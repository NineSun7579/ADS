#pragma once
#include "third_party/ranging_cpu/ranging.hpp"
#include "stable_cpu_ranging.h"
#include "mono_estimator.h"
#include "mono_motion.h"
#include "vision_types.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <opencv2/imgproc.hpp>
#include <condition_variable>
#include <chrono>
#include <deque>
#include <fstream>
#include <map>
#include <memory>
#include <mutex>
#include <thread>
#include <atomic>

namespace cpu_ranging {
struct WorkerStats {quint64 rebuilds=0,interruptions=0,overflowEvents=0,droppedFrames=0;};
constexpr int LifetimeMs=500;
struct Settings {
    bool enabled=false;
    QRect mark,road; // 640x480 analytics content pixels, never model padding
    QString standard;
    double laneWidthMeters=3.5,paintWidthMeters=.15; // Explicit physical assumptions; not image measurements.
    void useFullWidth() {
        const QRect bounds(0,0,640,480);
        for(auto* region:{&mark,&road})if(region->width()>=4 && region->height()>=4 && bounds.contains(*region)) {
            region->setLeft(0);region->setRight(639);
        }
    }
    bool ready() const {
        const QRect bounds(0,0,640,480);
        return std::isfinite(laneWidthMeters)&&laneWidthMeters>=2&&laneWidthMeters<=5.5&&
            std::isfinite(paintWidthMeters)&&paintWidthMeters>=.05&&paintWidthMeters<=.5&&
            mark.width()>=4 && mark.height()>=4 && road.width()>=4 && road.height()>=4 &&
            bounds.contains(mark) && bounds.contains(road) &&
            (standard=="city" || standard=="city-fast" || standard=="highway");
    }
};
inline QString configPath(){return qEnvironmentVariable("ADS_CPU_RANGING_CONFIG","/userdata/ads/cpu-ranging.json");}
inline QJsonArray rectJson(QRect r){return {r.x(),r.y(),r.width(),r.height()};}
inline QRect readRect(const QJsonValue& value) {
    const auto a=value.toArray();if(a.size()!=4)return {};
    for(auto v:a)if(!v.isDouble() || !std::isfinite(v.toDouble()) || v.toDouble()!=v.toInt(-1))return {};
    return {a[0].toInt(),a[1].toInt(),a[2].toInt(),a[3].toInt()};
}
using Configuration=std::map<QString,Settings>;
inline Configuration load(QString* error=nullptr) {
    Configuration result;QFile file(configPath());if(!file.exists())return result;
    if(!file.open(QIODevice::ReadOnly) || file.size()>262144){if(error)*error="CPU测距配置无法读取";return result;}
    QJsonParseError parse;const auto doc=QJsonDocument::fromJson(file.readAll(),&parse);
        if(parse.error!=QJsonParseError::NoError || !doc.isObject() || !doc.object().value("sources").isObject()) {
        if(error)*error="CPU测距配置格式无效";
        return result;
    }
    const auto sources=doc.object().value("sources").toObject();
    for(auto it=sources.begin();it!=sources.end();++it) {
        const auto o=it.value().toObject();Settings s;
        s.mark=readRect(o["mark"]);s.road=readRect(o["road"]);s.standard=o["standard"].toString();
        s.laneWidthMeters=o.value("lane_width_m").toDouble(3.5);s.paintWidthMeters=o.value("paint_width_m").toDouble(.15);
        s.useFullWidth();
        s.enabled=o["enabled"].toBool() && s.ready();result[it.key()]=s;
    }
    return result;
}
inline bool save(const Configuration& config,QString& error) {
    QJsonObject sources;
    for(const auto& entry:config) {
        auto s=entry.second;s.useFullWidth();
        if(s.enabled && !s.ready()){error="请先设置标线区、道路区和实际标线标准";return false;}
        sources[entry.first]=QJsonObject{{"enabled",s.enabled},{"mark",rectJson(s.mark)},
            {"road",rectJson(s.road)},{"standard",s.standard},
            {"lane_width_m",s.laneWidthMeters},{"paint_width_m",s.paintWidthMeters}};
    }
    QSaveFile file(configPath());
    if(!QDir().mkpath(QFileInfo(configPath()).absolutePath()) || !file.open(QIODevice::WriteOnly)) {
        error="CPU测距配置目录不可写";return false;
    }
    const auto bytes=QJsonDocument(QJsonObject{{"version",1},{"coordinates","content_640x480_xywh"},{"sources",sources}}).toJson();
    if(file.write(bytes)!=bytes.size() || !file.commit()){error="CPU测距配置保存失败";return false;}return true;
}
struct Sample {
    cpu_distance_quality::Bounds distanceBounds;
    quint64 frame=0;int generation=0;int camera=0;qint64 captured=0;QString source,reason;
    Settings settings;online_calib::State calibration;double milliseconds=0;int marks=0;
};
inline bool sameBox(const Detection& a,const Detection& b) {
    return a.cls==b.cls && a.x1==b.x1 && a.y1==b.y1 && a.x2==b.x2 && a.y2==b.y2 && a.score==b.score;
}

// ---- 单目部分解算：道路状态只由车道帧更新，目标米数由最新快照投影 ----
// 板上检测与车道两个模型按 NPU 任务交替跑（帧 N 检测、帧 N+1 车道），同帧证据几乎不存在，
// 所以这里不再要求“同帧”，而是：
//   1) 标签帧到达 → Worker 用自己的 RGB 环形缓存取“标签所属那一帧”的图像做测量；
//   2) 测量 → estimator.step() → 发布一份不可变快照（v_h/h_c/A/f/档位/车道线）；
//   3) 检测框在 annotate 里用最新快照纯计算投影，不与检测同帧、不经 Worker 队列。
struct MonoSnapshot {
    bool valid=false;
    int generation=0;
    quint64 frame=0;      // 产生这份快照的标签帧
    qint64 captured=0;    // 该标签帧的捕获时刻（与 capturedMs 同基准，用于算快照年龄）
    mono_partial::Estimator::Frame state;   // 自带车道线所有权，可跨线程只读
    mono_partial::Config config;
};
using MonoSnapshotPtr=std::shared_ptr<const MonoSnapshot>;

// 每秒日志与验收用的原子计数：全部**累计**（永不归零），日志自己算每秒增量。
// Worker 线程写前五项，annotate（GUI 线程）写 annotated/shown/age。
struct MonoCounters {
    std::atomic<quint64> laneEvidence{0},stepped{0},rgbMiss{0},staleDropped{0},annotated{0};
    std::atomic<quint64> shownApprox{0},shownUncertain{0},e1{0};
    static constexpr int AgeBuckets=10;              // 0-50, 50-100, …, 450-500ms
    std::atomic<quint64> age[AgeBuckets];
    MonoCounters(){for(auto& b:age)b.store(0);}
    void countAge(qint64 ms){
        int i=int(std::max<qint64>(0,std::min<qint64>(ms,499))/50);
        age[i].fetch_add(1,std::memory_order_relaxed);
    }
    // 一次读取（用于算窗口增量/给单测读总数）
    struct View {
        quint64 laneEvidence=0,stepped=0,rgbMiss=0,staleDropped=0,annotated=0,shownApprox=0,shownUncertain=0,e1=0;
        quint64 age[AgeBuckets]={};
        qint64 quantile(double q) const {
            quint64 total=0;for(auto v:age)total+=v;
            if(!total)return -1;
            const quint64 want=std::max<quint64>(1,quint64(double(total)*q));
            quint64 seen=0;
            for(int i=0;i<AgeBuckets;++i){seen+=age[i];if(seen>=want)return qint64(i)*50+25;}
            return 475;
        }
    };
    View view() const {
        View v;
        v.laneEvidence=laneEvidence.load();v.stepped=stepped.load();v.rgbMiss=rgbMiss.load();
        v.staleDropped=staleDropped.load();v.annotated=annotated.load();
        v.shownApprox=shownApprox.load();v.shownUncertain=shownUncertain.load();v.e1=e1.load();
        for(int i=0;i<AgeBuckets;++i)v.age[i]=age[i].load();
        return v;
    }
};

// 运动诊断导出：只写文件，绝不回读，也不作为下次启动的标定输入。
struct MonoTrace {
    std::mutex mu;
    std::ofstream out;
    bool ok=false;
    bool open(const QString& path){
        std::lock_guard<std::mutex> lock(mu);
        out.open(path.toStdString(),std::ios::out|std::ios::trunc);
        ok=out.is_open();
        if(ok)out<<"t_wall_s\tt_obs_s\tid\tz\tmethod\tgrade\tlane\tlaneKnown\toffset\toffsetKnown"
                   "\toffsetReason\tvz\tsigmaV\ttrend\tvelValid\tmotReason\tgeomChanged\tspanS\tn\n";
        return ok;
    }
    void row(double tWall,double tObs,uint64_t id,double z,int method,int grade,int lane,
             bool laneKnown,double offset,bool offsetKnown,const char* offsetReason,
             const mono_motion::Out& m){
        std::lock_guard<std::mutex> lock(mu);
        if(!ok)return;
        out<<tWall<<'\t'<<tObs<<'\t'<<id<<'\t'<<z<<'\t'<<method<<'\t'<<grade<<'\t'<<lane<<'\t'
           <<int(laneKnown)<<'\t'<<offset<<'\t'<<int(offsetKnown)<<'\t'<<offsetReason<<'\t'
           <<m.vz<<'\t'<<m.sigmaV<<'\t'<<mono_motion::trendName(m.trend)<<'\t'<<int(m.velValid)<<'\t'
           <<m.reason<<'\t'<<int(m.geomChanged)<<'\t'<<m.spanS<<'\t'<<m.n<<'\n';
    }
};

struct MonoAnnotateContext {
    MonoSnapshotPtr snapshot;
    MonoCounters* counters=nullptr;      // 可为空（旧调用点/单测）
    // ---- 目标运动（M1/M3，实验开关，默认关闭）----
    // motion 为空 = 功能关闭：不做任何运动写、不积累历史。
    std::shared_ptr<mono_motion::Bank> motion;
    std::shared_ptr<MonoTrace> trace;
    int timeBase=mono_motion::TimeBaseCapture;   // 观测时间的物理口径（视频回放要显式声明）
    uint64_t source=0;                           // 源标识（同一 ID 空间内区分来源）
    uint64_t continuity=0;                       // 视频循环代次
    bool hasContinuity=false;
};

// Annotation only joins the exact accepted raw box to its own source-frame
// calibration. Retained/predicted tracker boxes never inherit another frame's Z.
// 单目部分走另一条路：只要有新鲜快照就投影，不要求同帧（道路状态变化远慢于帧率）。
inline QVector<Detection> annotate(QVector<Detection> boxes,const QVector<Detection>& raw,
                                  const Sample& sample,quint64 frame,int generation,qint64 now,
                                  const MonoAnnotateContext& mono={}) {
    const MonoSnapshotPtr& snap=mono.snapshot;
    const qint64 monoAge=(snap && snap->valid)?now-snap->captured:-1;
    const bool monoFresh=snap && snap->valid && snap->generation==generation &&
                         monoAge>=0 && monoAge<=LifetimeMs;
    for(auto& d:boxes) {
        // Reused/predicted boxes must not retain a previous trusted offset.
        d.laneOffsetKnown=false;d.laneOffset=std::numeric_limits<float>::quiet_NaN();
        d.laneOffsetLocalKnown=false;d.laneOffsetLocal=std::numeric_limits<float>::quiet_NaN();
        d.laneOffsetReason=QStringLiteral("no_fresh_geometry");
        d.cpuDepthMeters=std::numeric_limits<double>::quiet_NaN();d.cpuDepthCapturedMs=0;
        d.monoMeters=std::numeric_limits<double>::quiet_NaN();d.monoCapturedMs=0;d.monoGrade=0;d.monoMethod=0;
        d.motionGeometryMs=0;d.motionA=d.motionVh=d.motionHc=std::numeric_limits<double>::quiet_NaN();
        d.motionValid=false;d.motionVz=d.motionSigmaV=std::numeric_limits<float>::quiet_NaN();d.motionTrend=0;
        // 旧路径：同帧标定，精确匹配原始框（保持不变）
        if(sample.frame==frame && sample.generation==generation && now>=sample.captured &&
           now-sample.captured<=LifetimeMs && !d.predicted) {
            const auto found=std::find_if(raw.begin(),raw.end(),[&](const Detection& r){return !r.predicted && sameBox(d,r);});
            if(found!=raw.end()) {
                ranging::Box box{d.cls,d.score,{d.x1,double(d.y1)-80,double(d.x2)-d.x1,double(d.y2)-d.y1}};
                const auto r=sample.settings.road;
                const auto measurement=cpu_distance_quality::project(box,sample.calibration,{640,480},{r.x(),r.y(),r.width(),r.height()},sample.distanceBounds);
                if(measurement.valid){d.cpuDepthMeters=measurement.depth_m;d.cpuDepthCapturedMs=sample.captured;}
            }
        }
        // 单目路径：最新快照投影；快照年龄 >200ms 一律带问号。
        if(monoFresh && !d.predicted) {
            d.motionA=snap->state.A;d.motionVh=snap->state.vh;d.motionHc=snap->state.hc;
            d.motionGeometryMs=snap->captured;
            const mono_partial::Box mb{d.x1,double(d.y1)-80,double(d.x2)-d.x1,double(d.y2)-d.y1,d.cls};
            const auto t=mono_partial::target(snap->state,mb,snap->config);
            // M2：车道内横向位置（与距离无关，缺边/窄缝时为未知）。
            d.laneOffsetKnown=t.laneOffsetKnown;
            d.laneOffset=float(t.laneOffset);
            d.laneOffsetLocal=float(t.laneOffsetLocal);
            d.laneOffsetLocalKnown=t.laneOffsetLocalKnown;
            d.laneOffsetReason=QString::fromLatin1(t.laneReason);
            if(std::isfinite(t.meters) && t.grade!=mono_partial::GradeNone) {
                d.monoMeters=t.meters;
                d.monoGrade=(t.grade==mono_partial::GradeApprox && monoAge<=200)?2:1;
                d.monoMethod=t.method==mono_partial::MethodGround?1:t.method==mono_partial::MethodWidth?2:0;
                d.monoCapturedMs=snap->captured;
                if(mono.counters) {
                    mono.counters->annotated.fetch_add(1,std::memory_order_relaxed);
                    mono.counters->countAge(monoAge);
                    if(d.monoGrade==2)mono.counters->shownApprox.fetch_add(1,std::memory_order_relaxed);
                    else mono.counters->shownUncertain.fetch_add(1,std::memory_order_relaxed);
                }
            }
            // M3：运动更新。观测时间必须来自该框自己（d.observedMs），不能拿 now；
            // 没有 ID / 没有观测时刻 / 时基未知时照样走一遍，由模块给出"未知"原因并计数。
            if(mono.motion) {
                mono_motion::Obs o;
                o.id=d.trackId;
                o.t=d.observedMs>0?double(d.observedMs)/1000.:std::numeric_limits<double>::quiet_NaN();
                o.footPx=double(d.y2)-80.;   // 640x480 分析坐标（已去 80px padding）
                o.zMeters=t.meters;
                o.A=snap->state.A;o.vh=snap->state.vh;
                o.tier=int(snap->state.tier);o.method=int(t.method);
                o.timeBase=mono.timeBase;
                o.source=mono.source;o.continuity=mono.continuity;o.hasContinuity=mono.hasContinuity;
                const auto m=mono.motion->update(o);
                d.motionValid=m.velValid;d.motionTrend=m.trend;
                d.motionVz=float(m.vz);d.motionSigmaV=float(m.sigmaV);
                if(mono.trace)mono.trace->row(double(now)/1000.,o.t,o.id,t.meters,int(t.method),
                                              int(t.grade),t.lane,t.laneKnown,t.laneOffset,
                                              t.laneOffsetKnown,t.laneReason,m);
            }
        }
    }
    return boxes;
}
// 状态行文本：状态机状态、当前档位（default 时标“默认2/4”）、A 的新鲜程度、h_c 与 v_h 来源、快照年龄。
inline QString monoStatusText(const MonoSnapshotPtr& snap,qint64 now) {
    if(!snap || !snap->valid)return QStringLiteral("单目：等待车道标签");
    const auto& f=snap->state;
    const qint64 age=now-snap->captured;
    const QString state=QString::fromUtf8(mono_partial::modeName(f.mode));
    const QString tier=f.mode==mono_partial::ModeDefault24?QStringLiteral("默认2/4"):QString::fromUtf8(mono_partial::tierName(f.tier));
    const QString source=f.hcSource==1?QStringLiteral("车道宽"):f.hcSource==2?QStringLiteral("标线宽"):
                        f.hcSource==3?QStringLiteral("车宽"):QStringLiteral("无");
    const QString a=std::isfinite(f.A)?QString("%1(%2s)").arg(f.A,0,'f',1)
                                        .arg(std::isfinite(f.aAge)?f.aAge:-1.,0,'f',1):QStringLiteral("无");
    return QString("单目 %1 · %2 · A=%3 · h_c=%4(%5) · v_h=%6 · 快照%7ms").arg(state,tier,a,
        std::isfinite(f.hc)?QString::number(f.hc,'f',2):QStringLiteral("-"),source,
        std::isfinite(f.vh)?QString::number(f.vh,'f',1):QStringLiteral("-")).arg(age<0?QStringLiteral("过期"):QString::number(age));
}

class Worker {
    struct Task {VisionFrame frame;QString source;Settings settings;quint64 revision=0,calibrationEpoch=0;bool preserveGeneration=false;};
    struct Stream {std::unique_ptr<stable_cpu_ranging::Engine> engine;int generation=-1;quint64 revision=0,lastFrame=0,continuity=0;int sequence=0;qint64 lastCaptured=0;};
    // 单目专用：最近 8 帧分析 RGB（QImage 隐式共享，不深拷贝）与同帧检测框
    struct RgbEntry {QImage image;int generation=0;qint64 captured=0;QString source;};
    struct DetectEntry {QVector<Detection> boxes;int generation=0;qint64 captured=0;};
    struct LaneJob {std::shared_ptr<const std::vector<uint8_t>> labels;quint64 frame=0;int generation=0;qint64 captured=0;quint64 epoch=0;QImage rgb;QString source;};
    // 单目估计器只被 monoThread 触碰；epoch 变化（切源/改几何）时整体重建。
    struct MonoState {std::unique_ptr<mono_partial::Estimator> est;quint64 epoch=0;int generation=-1;quint64 lastFrame=0;qint64 lastCaptured=0;mono_partial::Config config;};
    std::mutex mutex;std::condition_variable ready;std::condition_variable laneCv;bool stopping=false;
    quint64 revision=1;Configuration config;std::deque<Task> pending;
    quint64 calibrationEpoch=1;int preservedGeneration=-1;
    std::map<quint64,Sample> completed;std::map<QString,Stream> streams;
    std::map<quint64,RgbEntry> rgbRing;std::map<quint64,DetectEntry> detectRing;DetectEntry latestDetect;
    std::deque<LaneJob> laneJobs;MonoSnapshotPtr snapshot;
    std::map<QString,MonoState> monoStates;
    std::function<void()> completedHook;
    // 测量层入口：生产路径是 mono_partial::measure（真实图像 + 标签）。单测可替换它。
    std::function<mono_partial::Measurement(const cv::Mat&,const unsigned char*,
                                            const std::vector<mono_partial::Box>&)> monoMeasureHook;
    std::atomic<bool> monoEnabled{false};
    std::atomic<double> monoJobMs{0};   // 最近一次单目作业（measure+step）的耗时，供性能测试/上板核对
    std::atomic<quint64> rebuilds{0},interruptions{0},overflowEvents{0},droppedFrames{0};
    // 目标运动（实验开关）：默认关闭，关闭时为空指针，annotate 不做任何运动写。
    std::shared_ptr<mono_motion::Bank> motionBank;
    std::shared_ptr<MonoTrace> monoTrace;
    std::thread thread,monoThread;
    MonoCounters counters;
    // 每秒一条 [cpu-mono] 的统计窗口（只在本线程累加）
    qint64 monoLogAt=0;double monoLastMs=0;
    MonoCounters::View lastWindow;
    static constexpr int RgbRingFrames=8;        // 与标签最大延迟（~150ms）匹配
    static constexpr qint64 ApproxBoxAgeMs=200;  // 没有同帧检测框时，最近检测框的可用年龄
    void logMono(const MonoSnapshot& s,double ms) {
        const qint64 now=std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now().time_since_epoch()).count();
        if(monoLogAt==0){monoLogAt=now;return;}
        if(now-monoLogAt<1000)return;
        monoLogAt=now;
        // 计数是累计值，日志算“本秒增量”。
        const auto cur=counters.view();
        MonoCounters::View win;
        win.laneEvidence=cur.laneEvidence-lastWindow.laneEvidence;
        win.stepped=cur.stepped-lastWindow.stepped;
        win.rgbMiss=cur.rgbMiss-lastWindow.rgbMiss;
        win.staleDropped=cur.staleDropped-lastWindow.staleDropped;
        win.annotated=cur.annotated-lastWindow.annotated;
        win.shownApprox=cur.shownApprox-lastWindow.shownApprox;
        win.shownUncertain=cur.shownUncertain-lastWindow.shownUncertain;
        win.e1=cur.e1-lastWindow.e1;
        for(int i=0;i<MonoCounters::AgeBuckets;++i)win.age[i]=cur.age[i]-lastWindow.age[i];
        lastWindow=cur;
        const auto& f=s.state;
        const QString aText=std::isfinite(f.A)?QString::number(f.A,'f',1):QStringLiteral("-");
        const QString aAgeText=std::isfinite(f.aAge)?QString::number(f.aAge,'f',2):QStringLiteral("-");
        const QString hcText=std::isfinite(f.hc)?QString::number(f.hc,'f',2):QStringLiteral("-");
        const QString vhText=std::isfinite(f.vh)?QString::number(f.vh,'f',1):QStringLiteral("-");
        QString vhSrc;
        if(f.vhSourceMask&1)vhSrc+="vp";
        if(f.vhSourceMask&2)vhSrc+=(vhSrc.isEmpty()?"":"+")+QStringLiteral("lane");
        if(f.vhSourceMask&4)vhSrc+=(vhSrc.isEmpty()?"":"+")+QStringLiteral("paint");
        if(vhSrc.isEmpty())vhSrc="fallback";
        if(win.stepped)monoLastMs=ms;
        std::fprintf(stderr,
            "[cpu-mono] state=%s tier=%s p=[%.2f,%.2f,%.2f,%.2f] A=%s A_age=%s hc=%s(%s) vh=%s(%s) "
            "e1=%llu stepped=%llu lane_evidence=%llu rgb_miss=%llu stale_dropped=%llu "
            "annotated=%llu shown=approx:%llu uncertain:%llu snap_age_ms=p50:%lld/p95:%lld ms=%.2f\n",
            mono_partial::modeName(f.mode),mono_partial::tierName(f.tier),
            f.posterior[0],f.posterior[1],f.posterior[2],f.posterior[3],
            aText.toUtf8().constData(),aAgeText.toUtf8().constData(),
            hcText.toUtf8().constData(),
            f.hcSource==1?"lane":f.hcSource==2?"paint":f.hcSource==3?"vehicle":"none",
            vhText.toUtf8().constData(),vhSrc.toUtf8().constData(),
            (unsigned long long)win.e1,(unsigned long long)win.stepped,
            (unsigned long long)win.laneEvidence,(unsigned long long)win.rgbMiss,
            (unsigned long long)win.staleDropped,(unsigned long long)win.annotated,
            (unsigned long long)win.shownApprox,(unsigned long long)win.shownUncertain,
            (long long)win.quantile(.50),(long long)win.quantile(.95),monoLastMs);
    }
    static std::vector<mono_partial::Box> toMonoBoxes(const QVector<Detection>& boxes) {
        std::vector<mono_partial::Box> out;
        for(const auto& d:boxes) if(!d.predicted)
            out.push_back({d.x1,double(d.y1)-80,double(d.x2)-d.x1,double(d.y2)-d.y1,d.cls});
        return out;
    }
    // 单目线程：收到标签才动，按 frameId 取同一帧 RGB；只处理最新一份标签。
    void monoRun() {
        while(true) {
            LaneJob job;
            {
                std::unique_lock<std::mutex> lock(mutex);
                laneCv.wait(lock,[&]{return stopping||!laneJobs.empty();});
                if(stopping)return;
                job=std::move(laneJobs.back());
                if(laneJobs.size()>1)counters.staleDropped.fetch_add(laneJobs.size()-1);
                laneJobs.clear();
                if(!monoEnabled.load() || job.epoch!=calibrationEpoch)continue;
                auto it=rgbRing.find(job.frame);
                if(it==rgbRing.end() || it->second.generation!=job.generation) {
                    counters.rgbMiss.fetch_add(1);   // 同帧 RGB 不在缓存：丢弃，绝不拿别的帧顶替
                    continue;
                }
                job.rgb=it->second.image;
                job.source=it->second.source;
            }
            try { processLaneJob(job); }
            catch(const std::exception& e){ std::fprintf(stderr,"[cpu-mono] step failed: %s\n",e.what()); }
        }
    }
    void processLaneJob(const LaneJob& job) {
        std::vector<mono_partial::Box> boxes;
        std::function<mono_partial::Measurement(const cv::Mat&,const unsigned char*,
                                               const std::vector<mono_partial::Box>&)> measureFn;
        {
            std::lock_guard<std::mutex> lock(mutex);
            measureFn=monoMeasureHook;
            auto d=detectRing.find(job.frame);
            if(d!=detectRing.end() && d->second.generation==job.generation) {
                boxes=toMonoBoxes(d->second.boxes);          // 同帧检测框：精确遮挡
            } else if(!latestDetect.boxes.isEmpty() && latestDetect.generation==job.generation &&
                      job.captured>=latestDetect.captured && job.captured-latestDetect.captured<=ApproxBoxAgeMs) {
                boxes=toMonoBoxes(latestDetect.boxes);       // 最近检测框：近似遮挡
            }                                                // 都没有：不做遮挡剔除，仍然 step
        }
        auto& st=monoStates[job.source];
        if(!st.est || st.epoch!=job.epoch) st.est=std::make_unique<mono_partial::Estimator>(mono_partial::Config{});
        else if(job.generation!=st.generation || job.frame<=st.lastFrame || job.captured<st.lastCaptured) st.est->reset();
        st.epoch=job.epoch;st.generation=job.generation;
        const auto begin=std::chrono::steady_clock::now();
        const QImage image=job.rgb.convertToFormat(QImage::Format_RGB888);
        cv::Mat rgb(image.height(),image.width(),CV_8UC3,const_cast<uchar*>(image.constBits()),size_t(image.bytesPerLine())),bgr;
        cv::cvtColor(rgb,bgr,cv::COLOR_RGB2BGR);
        const auto measurement=measureFn?measureFn(bgr,job.labels->data(),boxes)
                                       :mono_partial::measure(bgr,job.labels->data(),boxes);
        const auto frame=st.est->step(double(job.captured)/1000.,measurement,boxes);
        st.config=st.est->config();
        st.lastFrame=job.frame;st.lastCaptured=job.captured;
        const double ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-begin).count();
        auto snap=std::make_shared<MonoSnapshot>();
        snap->valid=true;snap->generation=job.generation;snap->frame=job.frame;snap->captured=job.captured;
        snap->state=frame;snap->config=st.config;
        {std::lock_guard<std::mutex> lock(mutex);snapshot=snap;}
        counters.stepped.fetch_add(1);
        counters.e1.fetch_add(quint64(frame.e1Hits));
        monoJobMs.store(ms);
        logMono(*snap,ms);
    }
    void run() {
        while(true) {
            Task task;
            {std::unique_lock<std::mutex> lock(mutex);ready.wait(lock,[&]{return stopping||!pending.empty();});
             if(stopping)return;
             task=std::move(pending.front());pending.pop_front();}
            Sample sample;sample.frame=task.frame.frameId;sample.generation=task.frame.sourceGeneration;
            sample.camera=task.frame.camera;sample.source=task.source;sample.captured=task.frame.capturedMs;sample.settings=task.settings;
            const auto begin=std::chrono::steady_clock::now();
            try {
                auto& stream=streams[task.source];
                if(!stream.engine || (stream.generation!=sample.generation&&!task.preserveGeneration) || stream.revision!=task.calibrationEpoch) {
                    ranging::Config cfg;const auto m=task.settings.mark,r=task.settings.road;
                    cfg.mark={m.x(),m.y(),m.width(),m.height()};cfg.road={r.x(),r.y(),r.width(),r.height()};cfg.standard=task.settings.standard.toStdString();
                    stream.engine=std::make_unique<stable_cpu_ranging::Engine>(cfg,
                        stable_cpu_ranging::Widths{task.settings.laneWidthMeters,task.settings.paintWidthMeters});stream.sequence=0;
                    ++rebuilds;
                    stream.generation=sample.generation;stream.revision=task.calibrationEpoch;
                    stream.continuity=task.frame.continuity;
                } else if(stream.generation!=sample.generation || stream.continuity!=task.frame.continuity || sample.frame<=stream.lastFrame ||
                          sample.captured<stream.lastCaptured || sample.captured-stream.lastCaptured>1000) {
                    stream.engine->interrupt();stream.sequence=0;
                    ++interruptions;
                    stream.generation=sample.generation;
                    stream.continuity=task.frame.continuity;
                }
                const QImage image=task.frame.image.convertToFormat(QImage::Format_RGB888);
                if(image.size()!=QSize(640,480))throw std::invalid_argument("analytics image must be 640x480");
                cv::Mat rgb(image.height(),image.width(),CV_8UC3,const_cast<uchar*>(image.constBits()),size_t(image.bytesPerLine())),bgr;
                cv::cvtColor(rgb,bgr,cv::COLOR_RGB2BGR);
                const auto result=stream.engine->process(bgr,++stream.sequence,{},sample.captured);
                sample.calibration=result.calibration;sample.marks=result.marks;sample.reason=QString::fromStdString(result.calibration.why);
                sample.distanceBounds=stream.engine->distanceBounds;
                stream.lastFrame=sample.frame;stream.lastCaptured=sample.captured;
            } catch(const std::exception& error){sample.reason=QString::fromUtf8(error.what());sample.calibration={};}
            sample.milliseconds=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-begin).count();
            std::function<void()> hook;
            {std::lock_guard<std::mutex> lock(mutex);if(task.revision!=revision)continue;
             completed[sample.frame]=std::move(sample);while(completed.size()>48)completed.erase(completed.begin());hook=completedHook;}
            if(hook)hook();
        }
    }
public:
    WorkerStats stats() const {return {rebuilds.load(),interruptions.load(),overflowEvents.load(),droppedFrames.load()};}
    MonoCounters& monoCounters(){return counters;}
    Worker():motionBank(makeMotionBank()),monoTrace(makeMonoTrace()),thread([this]{run();}),monoThread([this]{monoRun();}){}
    ~Worker(){ {std::lock_guard<std::mutex> lock(mutex);stopping=true;}ready.notify_one();laneCv.notify_all();
               thread.join();monoThread.join();}
    Worker(const Worker&)=delete;Worker& operator=(const Worker&)=delete;
    void setCompletedHook(std::function<void()> hook){std::lock_guard<std::mutex> lock(mutex);completedHook=std::move(hook);}
    void setMonoMeasureHook(std::function<mono_partial::Measurement(const cv::Mat&,const unsigned char*,
                                                                    const std::vector<mono_partial::Box>&)> hook){
        std::lock_guard<std::mutex> lock(mutex);monoMeasureHook=std::move(hook);}
    // ADS_CPU_RANGE_SOURCE=mono 时打开；关闭时环形缓存与标签队列完全不动（legacy 行为与改动前一致）。
    void setMonoLaneEnabled(bool on) {
        std::lock_guard<std::mutex> lock(mutex);
        monoEnabled=on;
        if(!on){rgbRing.clear();detectRing.clear();latestDetect=DetectEntry{};laneJobs.clear();snapshot.reset();
                if(motionBank)motionBank->clear();}
    }
    MonoSnapshotPtr monoSnapshot() {std::lock_guard<std::mutex> lock(mutex);return snapshot;}
    double monoStepMs() const {return monoJobMs.load();}
    // 运动模块与诊断导出（只读句柄；开关关闭时为空）。
    std::shared_ptr<mono_motion::Bank> monoMotionBank(){return motionBank;}
    std::shared_ptr<MonoTrace> monoMotionTrace(){return monoTrace;}
    // 开关：ADS_MONO_MOTION=1 打开；ADS_MONO_MOTION_TRACE=<path> 导出逐目标 TSV。
    static std::shared_ptr<mono_motion::Bank> makeMotionBank(){
        if(qEnvironmentVariable("ADS_MONO_MOTION")!=QStringLiteral("1"))return nullptr;
        return std::make_shared<mono_motion::Bank>(mono_motion::Config{});
    }
    static std::shared_ptr<MonoTrace> makeMonoTrace(){
        const auto path=qEnvironmentVariable("ADS_MONO_MOTION_TRACE");
        if(path.isEmpty())return nullptr;
        auto trace=std::make_shared<MonoTrace>();
        if(!trace->open(path)){
            std::fprintf(stderr,"[mono-motion] trace open failed: %s\n",path.toUtf8().constData());
            return nullptr;
        }
        return trace;
    }
    void configure(Configuration settings){std::lock_guard<std::mutex> lock(mutex);config=std::move(settings);++revision;++calibrationEpoch;preservedGeneration=-1;pending.clear();completed.clear();
        rgbRing.clear();detectRing.clear();latestDetect=DetectEntry{};laneJobs.clear();snapshot.reset();
        if(motionBank)motionBank->clear();}
    void reset(bool preserve=false,int nextGeneration=-1){std::lock_guard<std::mutex> lock(mutex);++revision;
        if(!preserve)++calibrationEpoch;
        preservedGeneration=preserve?nextGeneration:-1;pending.clear();completed.clear();
        rgbRing.clear();detectRing.clear();latestDetect=DetectEntry{};laneJobs.clear();
        // 切源/改几何（calibrationEpoch 变化）必须立刻清空对外快照；同源 reset 只清时间轴，保留 A。
        if(!preserve)snapshot.reset();
        if(!preserve&&motionBank)motionBank->clear();}
    // post 线程（车道解码后）直接调用：只传标签与帧号，不经过 GUI，不再拷贝图像。
    void submitLaneEvidence(std::shared_ptr<const std::vector<uint8_t>> labels,quint64 frame,int generation,qint64 captured) {
        if(!monoEnabled.load() || !labels || labels->size()!=size_t(mono_partial::MaskW*mono_partial::MaskH))return;
        counters.laneEvidence.fetch_add(1);
        {
            std::lock_guard<std::mutex> lock(mutex);
            LaneJob job;job.labels=std::move(labels);job.frame=frame;job.generation=generation;
            job.captured=captured;job.epoch=calibrationEpoch;
            laneJobs.push_back(std::move(job));
            while(laneJobs.size()>4){laneJobs.pop_front();counters.staleDropped.fetch_add(1);}
        }
        laneCv.notify_one();
    }
    // 检测结果被接受时（GUI 线程）调用：给单目提供遮挡框，量很小，不含图像。
    void submitDetections(quint64 frame,int generation,qint64 captured,const QVector<Detection>& boxes) {
        if(!monoEnabled.load())return;
        std::lock_guard<std::mutex> lock(mutex);
        DetectEntry e;e.boxes=boxes;e.generation=generation;e.captured=captured;
        detectRing[frame]=e;
        while(detectRing.size()>RgbRingFrames)detectRing.erase(detectRing.begin());
        latestDetect=e;
    }
    void submit(const VisionFrame& frame,const QString& source) {
        std::lock_guard<std::mutex> lock(mutex);const auto found=config.find(source);
        if(found==config.end() || !found->second.enabled || !found->second.ready() || frame.image.isNull())return;
        // Overflow discards queued frames only. A source/configuration revision
        // is independent of scheduling pressure; current samples remain exact-frame.
        if(pending.size()>=8){droppedFrames+=pending.size();++overflowEvents;pending.clear();}
        auto owned=frame;owned.fpgaInput.reset(); // CPU owns RGB pixels only, never a DMA/NPU lease.
        if(monoEnabled.load()) {
            RgbEntry e;e.image=frame.image;e.generation=frame.sourceGeneration;e.captured=frame.capturedMs;e.source=source;
            rgbRing[frame.frameId]=e;
            while(rgbRing.size()>RgbRingFrames)rgbRing.erase(rgbRing.begin());
        }
        pending.push_back({std::move(owned),source,found->second,revision,calibrationEpoch,frame.sourceGeneration==preservedGeneration});ready.notify_one();
    }
    Sample get(quint64 frame,int generation) {
        std::lock_guard<std::mutex> lock(mutex);const auto found=completed.find(frame);
        return found!=completed.end() && found->second.generation==generation?found->second:Sample{};
    }
    Sample latest(const QString& source) {
        std::lock_guard<std::mutex> lock(mutex);
        for(auto it=completed.rbegin();it!=completed.rend();++it)if(it->second.source==source)return it->second;
        return {};
    }
};
}
