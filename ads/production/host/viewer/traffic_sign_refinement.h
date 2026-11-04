#pragma once
#include "vision_types.h"
#include <QImage>
#include <QPainter>
#include <QJsonArray>
#include <QJsonObject>
#include <QStringList>
#include <QMutex>
#include <QMutexLocker>
#include <deque>
#include <cmath>
#include <algorithm>

namespace sign_refine {
// Canonical class IDs from cloud_training_audit/tt100k_full/dataset.yaml.
inline QStringList classNames() {
    return {"i2","i4","i5","ip","p5","p10","p11","p19","p23","p26",
            "pg","ph4.5","pl20","pl30","pl40","pl50","pl60","pl70","pl80",
            "pl100","pl120","pm20","pne","ps","w13","w32","w55","w57","w59"};
}
struct Context {
    int generation = 0, camera = -1;
    quint64 epoch = 0, revision = 0;
    quint64 continuity = 0;
    acquisition::Ticket acquisition;
    bool operator==(const Context& b) const {
        return generation==b.generation && camera==b.camera && epoch==b.epoch && revision==b.revision &&
            continuity==b.continuity && acquisition.mask==b.acquisition.mask &&
            acquisition.epochs==b.acquisition.epochs;
    }
};
struct Crop {
    QImage rgb;
    QRect sourceRect;
    Detection original;
    QString model;
    quint64 frame = 0;
    int detectionIndex = -1;
    qint64 captured = -1;
};
struct Tile { Crop crop; QRect content; };
struct Job {
    QImage rgb;
    QVector<Tile> tiles;
    Context context;
    quint64 id = 0, serial = 0;
};
// All images are copied at detection publication, before a producer can reuse
// its buffer. Queue memory is <=16*192*192*3 bytes plus one 640-square job.
// A job is single-flight even across reset: an old completion only releases its
// own slot and cannot relabel crops from a new camera/video/model/epoch.
class Pipeline {
public:
    static constexpr int capacity = 16;
    static constexpr qint64 expiryMs = 750;
    void invalidate() {
        QMutexLocker lock(&mutex_); ++serial_; queue_.clear(); model_.clear(); valid_=false;
    }
    void context(const Context& context) {
        QMutexLocker lock(&mutex_);
        if (!valid_ || !(context_==context)) {
            context_=context; valid_=true; ++serial_; queue_.clear(); model_.clear();
        }
    }
    void offer(const Context& context, const QString& model, quint64 frame, qint64 captured,
               const QImage& canonical, const QVector<Detection>& detections,
               const QStringList& names, qint64 now) {
        QMutexLocker lock(&mutex_);
        if (!valid_ || !acquisition::current(context.acquisition) || !(context_==context) || canonical.size()!=QSize(640,640) ||
            captured<0 || now<captured || now-captured>expiryMs) return;
        if (!model_.isEmpty() && model_!=model) { ++serial_; queue_.clear(); }
        model_=model;
        prune(now);
        for (int i=0;i<detections.size();++i) {
            const auto& d=detections[i];
            if (names.value(d.cls)!="traffic_sign" || !std::isfinite(d.x1) || !std::isfinite(d.x2) ||
                !std::isfinite(d.y1) || !std::isfinite(d.y2) || d.x2<=d.x1 || d.y2<=d.y1) continue;
            // Clamp in float before converting to int (malformed tensor values
            // must never overflow a QRect or allocate an unbounded image).
            const int x1=int(std::floor(std::max(0.f,std::min(640.f,d.x1))));
            const int y1=int(std::floor(std::max(0.f,std::min(640.f,d.y1))));
            const int x2=int(std::ceil(std::max(0.f,std::min(640.f,d.x2))));
            const int y2=int(std::ceil(std::max(0.f,std::min(640.f,d.y2))));
            const QRect rect(x1,y1,x2-x1,y2-y1);
            if (rect.width()<2 || rect.height()<2) continue;
            Crop crop; crop.sourceRect=rect; crop.original=d; crop.model=model;
            crop.frame=frame; crop.detectionIndex=i; crop.captured=captured;
            crop.rgb=canonical.copy(rect).scaled(192,192,Qt::KeepAspectRatio,Qt::SmoothTransformation)
                .convertToFormat(QImage::Format_RGB888);
            if (crop.rgb.isNull()) continue;
            if (queue_.size()>=capacity) queue_.pop_front();
            queue_.push_back(std::move(crop));
        }
    }
    Job take(qint64 now) {
        QMutexLocker lock(&mutex_);
        prune(now);
        if (!valid_ || !acquisition::current(context_.acquisition) || busy_ || queue_.empty() || (lastStart_>=0 && now-lastStart_<100)) return {};
        Job job; job.id=++sequence_; job.serial=serial_; job.context=context_;
        job.rgb=QImage(640,640,QImage::Format_RGB888); job.rgb.fill(qRgb(114,114,114));
        QPainter painter(&job.rgb);
        const int count=std::min(4,int(queue_.size()));
        for (int i=0;i<count;++i) {
            Tile tile; tile.crop=std::move(queue_.front()); queue_.pop_front();
            const QSize size=tile.crop.rgb.size().scaled(304,304,Qt::KeepAspectRatio);
            tile.content=QRect(QPoint((i%2)*320+(320-size.width())/2,
                                     (i/2)*320+(320-size.height())/2),size);
            painter.drawImage(tile.content,tile.crop.rgb); job.tiles.push_back(std::move(tile));
        }
        painter.end(); busy_=true; active_=job; lastStart_=now;
        return job;
    }
    // Only TT100K results fully inside a tile's content may map back. Padding,
    // seams, invalid classes, stale crops, and superseded jobs are rejected.
    QJsonObject complete(quint64 id, const QVector<Detection>& detections, qint64 now) {
        QMutexLocker lock(&mutex_);
        if (!busy_ || active_.id!=id) return {};
        Job job=std::move(active_); active_={}; busy_=false;
        if (!valid_ || !acquisition::current(job.context.acquisition) || job.serial!=serial_ || !(job.context==context_)) return {};
        QJsonArray results;
        const auto names=classNames();
        for (const auto& tile:job.tiles) {
            const auto& crop=tile.crop;
            if (now<crop.captured || now-crop.captured>expiryMs) continue;
            const Detection* best=nullptr;
            for (const auto& d:detections) {
                if (d.cls<0 || d.cls>=names.size() || !std::isfinite(d.score) ||
                    !std::isfinite(d.x1) || !std::isfinite(d.y1) || !std::isfinite(d.x2) ||
                    !std::isfinite(d.y2) || d.x2<=d.x1 || d.y2<=d.y1 ||
                    d.x1<tile.content.x() || d.y1<tile.content.y() ||
                    d.x2>tile.content.x()+tile.content.width() ||
                    d.y2>tile.content.y()+tile.content.height()) continue;
                if (!best || d.score>best->score) best=&d;
            }
            if (!best) continue;
            const auto& d=*best;
            const double sx=double(crop.sourceRect.width())/tile.content.width();
            const double sy=double(crop.sourceRect.height())/tile.content.height();
            results.append(QJsonObject{{"frame",QString::number(crop.frame)},
                {"parent_model",crop.model},{"detection_index",crop.detectionIndex},
                {"captured_ms",double(crop.captured)}, {"class_id",d.cls},{"class_name",names[d.cls]},
                {"score",d.score}, {"parent_xyxy",QJsonArray{crop.original.x1,crop.original.y1,crop.original.x2,crop.original.y2}},
                {"xyxy",QJsonArray{crop.sourceRect.x()+(d.x1-tile.content.x())*sx,
                    crop.sourceRect.y()+(d.y1-tile.content.y())*sy,
                    crop.sourceRect.x()+(d.x2-tile.content.x())*sx,
                    crop.sourceRect.y()+(d.y2-tile.content.y())*sy}}});
        }
        return {{"schema","tt100k-crop-v1"},{"coordinate_space","canonical_640x640"},
            {"generation",job.context.generation},{"camera",job.context.camera},
            {"epoch",QString::number(job.context.epoch)},{"model_revision",QString::number(job.context.revision)},
            {"source_kind",job.context.acquisition.mask?"camera":"video"},
            {"continuity",QString::number(job.context.continuity)},
            {"job",QString::number(id)},{"completed_ms",double(now)},{"results",results}};
    }
    void failed(quint64 id) { complete(id,{},0); }
private:
    void prune(qint64 now) {
        queue_.erase(std::remove_if(queue_.begin(),queue_.end(),[now](const Crop& c){
            return now<c.captured || now-c.captured>expiryMs;
        }),queue_.end());
    }
    QMutex mutex_;
    Context context_;
    bool valid_=false, busy_=false;
    quint64 serial_=0, sequence_=0;
    qint64 lastStart_=-1;
    QString model_;
    std::deque<Crop> queue_;
    Job active_;
};
} // namespace sign_refine
