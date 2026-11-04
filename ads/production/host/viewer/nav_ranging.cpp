#include "nav_ranging.h"
#include "third_party/navlite/async_nav.hpp"
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStringList>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <condition_variable>
#include <mutex>
#include <thread>
#include <chrono>

namespace ads_nav {
QString configPath(){return qEnvironmentVariable("ADS_NAV_CONFIG","/userdata/ads/navigation.json");}
Configuration load(QString* error){
    Configuration result;QFile file(configPath());if(!file.exists())return result;
    if(!file.open(QIODevice::ReadOnly)){if(error)*error=file.errorString();return result;}
    QJsonParseError parse;const auto doc=QJsonDocument::fromJson(file.readAll(),&parse);
    if(parse.error!=QJsonParseError::NoError||!doc.isObject()||doc.object()["version"].toInt()!=1){if(error)*error=QStringLiteral("导航配置无效");return result;}
    const auto root=doc.object();result.camera=std::max(0,std::min(6,root["camera"].toInt(6)));
    const auto sources=root["sources"].toObject();
    for(auto it=sources.begin();it!=sources.end();++it){const auto o=it.value().toObject();const auto a=o["region"].toArray();Settings s;
        if(a.size()==4)s.region={a[0].toInt(),a[1].toInt(),a[2].toInt(),a[3].toInt()};
        s.enabled=o["enabled"].toBool()&&s.ready();result.sources[it.key()]=s;}
    return result;
}
bool save(const Configuration& c,QString& error){
    QJsonObject sources;for(auto it=c.sources.begin();it!=c.sources.end();++it){const auto s=it.value();if(s.enabled&&!s.ready()){error=QStringLiteral("请先圈定导航区域");return false;}
        sources[it.key()]=QJsonObject{{"enabled",s.enabled},{"region",QJsonArray{s.region.x(),s.region.y(),s.region.width(),s.region.height()}}};}
    QDir().mkpath(QFileInfo(configPath()).absolutePath());QSaveFile file(configPath());
    if(!file.open(QIODevice::WriteOnly)){error=file.errorString();return false;}
    if(file.write(QJsonDocument(QJsonObject{{"version",1},{"coordinates","analytics_640x480_xywh"},{"camera",c.camera},{"sources",sources}}).toJson())<0||!file.commit()){error=file.errorString();return false;}return true;
}
struct Worker::Impl {
    struct Task {VisionFrame frame;QString source;Settings settings;quint64 revision=0;};
    mutable std::mutex mutex;std::condition_variable wake;bool closing=false,hasTask=false;quint64 revision=1;
    Configuration config;Task task;Sample sample;QString models;std::thread worker;
    explicit Impl(QString directory):models(std::move(directory)),worker([this]{run();}){}
    ~Impl(){{std::lock_guard<std::mutex> lock(mutex);closing=true;}wake.notify_one();worker.join();}
    void run(){
        const bool trace=qEnvironmentVariableIsSet("ADS_NAV_TRACE");
        std::unique_ptr<navasync::Pipeline> pipeline;QString source;quint64 epoch=0,continuity=0,lastFrame=0;int generation=-1,sequence=0;qint64 lastTime=-1;
        std::map<int,quint64> frameIds;QString failedSource;quint64 failedRevision=0;qint64 retryAfter=0;
        while(true){Task next;
            {std::unique_lock<std::mutex> lock(mutex);wake.wait(lock,[&]{return closing||hasTask;});if(closing)return;next=std::move(task);hasTask=false;}
            if(failedRevision==next.revision&&failedSource==next.source&&next.frame.capturedMs<retryAfter)continue;
            Sample output;output.source=next.source;output.frame=next.frame.frameId;output.generation=next.frame.sourceGeneration;output.continuity=next.frame.continuity;output.captured=next.frame.capturedMs;
            try {
                // Processing/model warmup delays are not source discontinuities.
                // State::advance handles motion gaps without discarding the reader.
                if(!pipeline||source!=next.source||epoch!=next.revision||generation!=next.frame.sourceGeneration||continuity!=next.frame.continuity||next.frame.frameId<=lastFrame||next.frame.capturedMs<=lastTime){
                    if(trace)fprintf(stderr,"[ads-navigation-trace] reset had_pipeline=%d source=%d revision=%d generation=%d continuity=%d backwards_frame=%d backwards_time=%d gap_ms=%lld\n",bool(pipeline),source!=next.source,epoch!=next.revision,generation!=next.frame.sourceGeneration,continuity!=next.frame.continuity,next.frame.frameId<=lastFrame,next.frame.capturedMs<=lastTime,static_cast<long long>(next.frame.capturedMs-lastTime));
                    const auto initStart=std::chrono::steady_clock::now();
                    pipeline.reset();navasync::Config cfg;
                    cfg.lineUnits=cfg.jointRoles=cfg.sampledArrows=cfg.retainOnReadFailure=cfg.completeDigits=true;
                    cfg.coherentRows=false;cfg.regionIdentity=cfg.rowScale=cfg.strictEvidence=cfg.refinedTurns=cfg.stableUnits=cfg.recoverIdentity=cfg.splitDigits=cfg.lazyRejectedUnits=true;
                    cfg.verifyWeakContent=cfg.publicationContext=cfg.retainNumericGeometry=true;cfg.refreshJobs=90;cfg.localMissLimit=6;
                    cfg.exactLegacyArrows=cfg.mergeArrowPasses=cfg.reuseUnitPreparation=true;
                    cfg.digitRejectModel=(models+"/reject.yml").toStdString();
                    pipeline=std::make_unique<navasync::Pipeline>((models+"/base.yml").toStdString(),cfg);
                    if(trace)fprintf(stderr,"[ads-navigation-trace] init_ms=%lld\n",static_cast<long long>(std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now()-initStart).count()));
                    source=next.source;epoch=next.revision;generation=next.frame.sourceGeneration;continuity=next.frame.continuity;sequence=0;frameIds.clear();
                }
                const auto rgb=next.frame.image.convertToFormat(QImage::Format_RGB888);if(rgb.size()!=QSize(640,480))throw std::runtime_error("navigation requires 640x480 analytics image");
                cv::Mat pixels(rgb.height(),rgb.width(),CV_8UC3,const_cast<uchar*>(rgb.constBits()),size_t(rgb.bytesPerLine())),bgr;
                const auto r=next.settings.region;cv::cvtColor(pixels(cv::Rect(r.x(),r.y(),r.width(),r.height())),bgr,cv::COLOR_RGB2BGR);
                frameIds[++sequence]=next.frame.frameId;while(frameIds.size()>120)frameIds.erase(frameIds.begin());
                navasync::Event event;const bool received=pipeline->update(bgr,sequence,next.frame.capturedMs/1000.,event);
                if(trace&&received)fprintf(stderr,"[ads-navigation-trace] event status=%s why=%s published=%d compute_ms=%.1f age_ms=%.1f\n",event.status.c_str(),event.why.c_str(),event.published,event.outcome.computeMs,event.age*1000);
                lastFrame=next.frame.frameId;lastTime=next.frame.capturedMs;
                output.status=QStringLiteral("搜索导航提示");
                if(received){output.status=event.published?QStringLiteral("已识别导航提示"):event.status=="PROVISIONAL"?QStringLiteral("等待下一次识别确认"):QStringLiteral("未获得可靠导航读数");output.computeMs=event.outcome.computeMs;
                    output.captured=qRound64(event.outcome.job.source.source*1000);output.published=event.published;
                    const auto original=frameIds.find(event.outcome.job.source.id);output.frame=original==frameIds.end()?0:original->second;if(!output.frame)output.published=false;
                    if(event.published){const auto& row=event.outcome.row;output.number=QString::fromStdString(row.number);output.unit=navlite::multiplier(row.unit.label)==1000?"km":"m";output.meters=row.meters;
                        QStringList turns;for(const auto& arrow:row.arrows){const auto direction=QString::fromStdString(arrow.direction);if(!turns.contains(direction))turns<<direction;}output.directions=turns.join(" / ");}}
                {std::lock_guard<std::mutex> lock(mutex);if(next.revision==revision){
                    // No new event may leave a still-fresh source read visible;
                    // reject/provisional events always clear the previous number.
                    if(!received&&sample.source==output.source&&!sample.status.isEmpty())output.status=sample.status;
                    if(!received&&pipeline->positions().trustedPosition()&&sample.source==output.source&&sample.published){sample.status=output.status;}
                    else sample=std::move(output);
                }}
            }catch(const std::exception& e){pipeline.reset();failedSource=next.source;failedRevision=next.revision;retryAfter=next.frame.capturedMs+1000;output.published=false;output.status=QStringLiteral("导航识别暂不可用，请检查区域和模型文件");fprintf(stderr,"[ads-navigation] error=%s\n",e.what());std::lock_guard<std::mutex> lock(mutex);if(next.revision==revision)sample=std::move(output);}
        }
    }
};
Worker::Worker(QString directory){if(directory.isEmpty())directory=qEnvironmentVariable("ADS_NAV_MODELS",QCoreApplication::applicationDirPath()+"/navlite/models");impl=std::make_unique<Impl>(directory);}
Worker::~Worker()=default;
void Worker::configure(Configuration config){std::lock_guard<std::mutex> lock(impl->mutex);impl->config=std::move(config);++impl->revision;impl->hasTask=false;impl->sample={};}
void Worker::reset(){std::lock_guard<std::mutex> lock(impl->mutex);++impl->revision;impl->hasTask=false;impl->sample={};}
void Worker::submit(const VisionFrame& frame,const QString& source){
    std::lock_guard<std::mutex> lock(impl->mutex);const auto found=impl->config.sources.constFind(source);
    if(found==impl->config.sources.cend()||!found->enabled||!found->ready()||frame.image.isNull())return;
    if(source.startsWith("camera:")&&source!=QString("camera:%1").arg(impl->config.camera))return;
    auto owned=frame;owned.fpgaInput.reset();impl->task={std::move(owned),source,*found,impl->revision};impl->hasTask=true;impl->wake.notify_one();
}
Sample Worker::latest(const QString& source)const{std::lock_guard<std::mutex> lock(impl->mutex);return impl->sample.source==source?impl->sample:Sample{};}
QString displayKey(const Sample& s,qint64 now){if(!s.fresh(now))return QStringLiteral("导航：暂无有效读数");
    QString turns=s.directions.toLower();turns.replace("straight","直行").replace("left","左转").replace("right","右转").replace("uturn","掉头");
    return QString("导航来源读数：%1%2 · %3").arg(s.number,s.unit,turns);}
QString display(const Sample& s,qint64 now){if(!s.fresh(now))return QStringLiteral("导航：暂无有效读数");
    QString turns=s.directions.toLower();turns.replace("straight","直行").replace("left","左转").replace("right","右转").replace("uturn","掉头");
    return QString("导航来源读数：%1%2 · %3（%4秒前）").arg(s.number,s.unit,turns).arg((now-s.captured)/1000.,0,'f',1);}
}
