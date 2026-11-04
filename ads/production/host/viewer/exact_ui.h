#pragma once

// Native Qt5 presentation of pages/{index,six-channel,four-channel,hdmi-input}.html.
// Coordinates are logical QOpenGLWindow pixels, never device pixels. No I/O or
// hardware state is manufactured here. Resolution is a draft; hd is live state.
#include <QPainter>
#include <QImage>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>
#include <cstdio>
#include <QPainterPath>
#include <QRegion>
#include <QFontMetricsF>
#include <QStringList>
#include <QVector>
#include <QSet>
#include <QPair>
#include <QMap>
#include <QVariant>
#include "shortcuts.h"
#include <QSize>
#include <QDateTime>
#include <QRectF>
#include <array>
#include <algorithm>
#include <cmath>
#include "detection_style.h"
#include "lane_style.h"
#include "status_bar.h"
#include "vehicle_action_state.h"
#include "replay_lane_change_policy.h"
#include "driving_controls_panel.h"
#include "recognition_legend_panel.h"

namespace exact_ui {
enum class Page { Home, Six, Four, Hdmi };
struct Action {
    enum Kind { None, Navigate, Apply, Resolution, Confidence, Zoom, Ranging, Model, Panorama, Lamp, LocalVideo, VideoPause, VideoLoop, TagScroll, LightRegion, CpuRanging, CpuRegion, LightCount, ViewerControl, DriveControl, NavigationSettings, NavigationRegion, HdmiPanorama };
    Kind kind = None;
    int camera = -1;
    int value = 0;
    Page page = Page::Home;
    QRectF region;
};
struct VideoTile { int camera; QRectF rect; };
struct Control { QString id, label; QRectF rect; bool enabled = true; };
struct LegendEntry {
    QString text; QColor color; bool heading=false;
};
inline QVector<LegendEntry> recognitionLegend() {
    QVector<LegendEntry> result{{"目标类别",{},true}};
    for(const auto* name:{"car","bus","truck","person","rider","bike","motor",
                         "tl_red","tl_yellow","tl_green","traffic_sign"})
        result.push_back({detection_style::label(name),detection_style::color(name),false});
    result.push_back({"道路标线",{},true});
    for(int id:{1,2,3,4,5,6,8,9,10,11}) {
        QColor swatch=QColor::fromRgba(lane_style::rgba(id));swatch.setAlpha(255);
        result.push_back({lane_style::label(id),swatch,false});
    }
    return result;
}

class Frontend {
public:
    Page page = Page::Home;
    int zoomCamera = -1;
    bool ranging = false;
    bool panorama = false;
    bool shortcutHelp = false;   // ? 帮助浮层
    double confidence = .5;
    QString status;
    QString drivingHint;
    QJsonObject drivingState;
    bool selectingLightRegion=false;
    QRectF aheadLightRegion;
    int expectedLightGroups=0;
    QString frameStatus;
    QVector<LegendEntry> legend=recognitionLegend();
    QStringList localVideos;
    QString localVideoName;
    QString localVideoStatus;
    bool localVideoActive=false, localVideoPaused=false, localVideoLoop=true;
    bool hdmiPanoramaActive=false;
    QImage lanePreview;
    // Home「城市道路感知」页：识别对照浮层开关、统计条计数与推理帧率文本。
    // 计数和推理帧率由 main 按现有检测结果/线程指标填写，UI 只展示，不另造数据源。
    bool homeLegend=false;
    bool homeToolsPanel=false;
    std::array<int,5> homeClassCounts{{0,0,0,0,0}}; // 机动车/行人/自行车/公交车/摩托车
    int homeFusedCount=0;
    QString inferenceRate;
    bool cpuPanel=false,cpuEnabled=false;
    bool navPanel=false,navSelecting=false,navEnabled=false;
    int navCamera=6;QRectF navRegion;QString navStatus,navReadout;
    bool displayPanel=false,recognitionRunning=true,showConfidence=true,showDistance=true,showIntent=true;
    bool showLaneOutput=true,showObjectOutput=true;
    bool drivingRequested=false,aebWarning=false;
    // Explicit UI history: default false/zero values are not user selections.
    bool driveSelectionMade=false,laneSelectionMade=false;
    // Explicit ui.prediction* variants rebuilt from engine output, or the
    // isolated t1 signal preview below. FSM defaults never imply permission.
    QMap<QString,QVariant> predictionStates;
    // Display-only t1 Replay policy; never enabled for the live Frontend/FSM.
    static constexpr bool replaySignalPredictions=false;
    static constexpr bool replayLaneChangePredictions=false;
    static constexpr bool replayEmergencyPredictions=false;
    bool replayEmergencyBlinkPhase=true;
    bool updateReplayEmergencyClock(qint64 wallNow) {
        const bool phase=status_bar::blinkPhase(wallNow);
        const bool changed=phase!=replayEmergencyBlinkPhase;
        replayEmergencyBlinkPhase=phase;
        return replayEmergencyPredictions&&changed&&
            predictionStates.value(QStringLiteral("ui.predictionEmergency.blink"),false).toBool();
    }
    replay_lane_change::Policy replayLaneChangePolicy;
    qint64 replayLaneChangeSourceNow=-1;
    bool updateReplayLaneChangeClock(qint64 wallNow) {
        if(!replayLaneChangePredictions)return false;
        replayLaneChangePolicy.wallNow=wallNow;
        auto values=predictionStates;
        replayLaneChangePolicy.render(actionInput(replayLaneChangeSourceNow),values);
        if(values==predictionStates)return false;
        predictionStates=values;return true;
    }
    int assumedLane=0,changeRequest=0; // -1 left, 0 straight/none, +1 right
    qint64 driveWarningUntil=0;
    int driveFeedbackControl=-1;
    qint64 driveFeedbackUntil=0;
    QString pressedDrive;
    vehicle_action::Engine vehicleActionEngine;
    vehicle_action::Result vehicleAction;
    bool statusBlinkPhase=true;
    QString vehicleActionSource=QStringLiteral("unconfigured");
    struct LaneChangeRequest {
        int direction=0;
        quint64 serial=0,sourceEpoch=0;
        qint64 startedAt=-1;
    };
    LaneChangeRequest laneChangeRequest() const {
        return {changeRequest,changeSerial_,changeSourceEpoch_,changeStartedAt_};
    }
    // GUI-thread seam for a real motion producer. All times use the same clock
    // as updateVehicleAction. No uncorrelated adapter JSON can complete a request.
    bool observeLaneChangeFeedback(const LaneChangeRequest& request,bool valid,
            bool changing,bool crossed,bool reached,qint64 captured,qint64 now) {
        if(!changeRequest || request.direction!=changeRequest ||
           request.serial!=changeSerial_ || request.sourceEpoch!=changeSourceEpoch_ ||
           changeStartedAt_<0 || !valid || captured<=changeStartedAt_ ||
           captured<=changeFeedbackAt_ || captured>now || now-captured>500)return false;
        changeFeedbackAt_=captured;
        if(changing&&!reached)changeMotionAt_=captured;
        if(changeMotionAt_<0 || captured<=changeMotionAt_ || changing || !crossed || !reached)return false;
        cancelLaneChange();updateVehicleAction(now);return true;
    }
private:
    quint64 changeSerial_=0,changeSourceEpoch_=0;
    qint64 changeStartedAt_=-1,changeFeedbackAt_=-1,changeMotionAt_=-1;
    void cancelLaneChange() {
        changeRequest=0;changeStartedAt_=changeFeedbackAt_=changeMotionAt_=-1;
    }
public:
    vehicle_action::Input actionInput(qint64 now) const {
        vehicle_action::Input in;in.now=now;in.requested=drivingRequested;
        in.assumedLane=assumedLane;in.changeRequest=changeRequest;
        in.recognition=recognitionRunning;in.evidence=drivingState;
        // The measured AEB path is camera-aligned straight only. A turn or
        // lane change has no measured ego path here; never invent its conflict.
        if(replayEmergencyPredictions&&(in.assumedLane!=0||in.changeRequest!=0))
            in.evidence.remove(QStringLiteral("aeb_trajectory"));
        return in;
    }
    bool updateVehicleAction(qint64 now) {
        if(changeRequest && changeStartedAt_<0)changeStartedAt_=now;
        const auto in=actionInput(now);
        auto next=vehicleActionEngine.update(in);
        if(replayEmergencyPredictions&&(in.assumedLane!=0||in.changeRequest!=0))
            next.aeb[QStringLiteral("reason")]=QStringLiteral("intended_path_not_measured");
        const QString predictionKeys[]={QStringLiteral("ui.predictionLeft"),
            QStringLiteral("ui.predictionStraight"),QStringLiteral("ui.predictionRight"),
            QStringLiteral("ui.predictionViolation"),QStringLiteral("ui.predictionEmergency")};
        QMap<QString,QVariant> predictions;
        for(int i=0;i<5;++i) {
            const auto color=next.cards[size_t(i)].color;
            // Engine Green/Red cards carry evaluated permission/conflict or
            // verified risk. Yellow is pending/insufficient, not permission.
            predictions[predictionKeys[i]]=in.requested&&color==vehicle_action::Color::Green?
                QStringLiteral("active"):in.requested&&color==vehicle_action::Color::Red?
                QStringLiteral("warning"):QStringLiteral("normal");
        }
        const bool explicitStop=driveSelectionMade&&!in.requested;
        const bool businessStop=in.requested&&next.action==QStringLiteral("stop")&&
            next.state!=QStringLiteral("Stopped")&&next.state!=QStringLiteral("Waiting");
        predictions[QStringLiteral("ui.predictionStop")]=explicitStop||businessStop?
            QStringLiteral("warning"):QStringLiteral("normal");
        if(replaySignalPredictions) {
            // A same-frame, direction-owned signal can predict the next action
            // without a drive request or lane geometry. It cannot grant Allowed.
            const auto signal=[&](int lane) {
                const QString direction=lane<0?QStringLiteral("left"):
                    lane>0?QStringLiteral("right"):QStringLiteral("straight");
                const int slot=lane<0?0:lane>0?2:1;
                if(!in.recognition||in.evidence["timestamp_ms"].toDouble(-1)!=double(now)||
                   !in.evidence["lights_fresh"].toBool()||!in.evidence["lights_stable"].toBool()||
                   !in.evidence["ahead_roi_configured"].toBool()||
                   !in.evidence["traffic_temporal"].toBool()||
                   !in.evidence["traffic_mapping_confirmed"].toBool()||
                   in.evidence["expected_light_groups"].toInt()!=2||
                   !vehicle_action::fresh(vehicle_action::age(in,"detection_age_ms")))return 0;
                bool owned=false;
                for(const auto& entry:in.evidence["replay_direction_sources"].toArray()) {
                    const auto origin=entry.toObject();
                    if(origin["suite"].toString()==QStringLiteral("t1")&&
                       origin["variant"].toString()==direction&&origin["slot"].toInt(-1)==slot&&
                       origin["now_ms"].toDouble(-1)==double(now))owned=true;
                }
                if(!owned)return 0;
                const int permission=in.evidence[direction].toInt();
                for(const auto& entry:in.evidence["light_groups"].toArray()) {
                    const auto group=entry.toObject();
                    if(group["slot"].toInt(-1)==slot&&group["current"].toBool()&&
                       group["confirmed"].toBool()&&group["mapping_confirmed"].toBool()&&
                       group["timestamp_ms"].toDouble(-1)==double(now)&&
                       ((permission==2&&group["color"].toInt()==1)||
                        (permission==1&&group["color"].toInt()==3)))return permission;
                }
                return 0;
            };
            const int light=signal(in.assumedLane);
            for(int i=0;i<4;++i)predictions[predictionKeys[i]]=QStringLiteral("normal");
            predictions[QStringLiteral("ui.predictionStop")]=light==2?
                QStringLiteral("warning"):QStringLiteral("normal");
            if(light==1&&in.assumedLane>=-1&&in.assumedLane<=1)
                predictions[predictionKeys[in.assumedLane+1]]=QStringLiteral("active");
            if(in.requested&&light==2)
                predictions[QStringLiteral("ui.predictionViolation")]=QStringLiteral("warning");
            for(int i=0;i<4;++i)
                predictions[predictionKeys[i]+QStringLiteral(".blink")]=true;
            predictions[QStringLiteral("ui.predictionStop.blink")]=true;
        }
        if(replayLaneChangePredictions) {
            replayLaneChangeSourceNow=now;
            replayLaneChangePolicy.render(in,predictions);
        }
        if(replayEmergencyPredictions) {
            // Keep the existing latch/stop rule. Only a currently verified
            // trajectory risk flashes; the remaining latched warning is steady.
            predictions[QStringLiteral("ui.predictionEmergency.blink")]=
                next.aeb[QStringLiteral("risk")].toBool()&&
                predictions.value(QStringLiteral("ui.predictionEmergency")).toString()==QStringLiteral("warning");
        }
        const bool predictionsChanged=predictions!=predictionStates;
        predictionStates=predictions; // Replace, including normal, to clear stale output.
        const bool changed=next.json()!=vehicleAction.json();
        if(changed) {
            QJsonObject log{{"previous",vehicleAction.json()},{"next",next.json()},
                {"action",next.action},{"reason",next.reason},{"source",vehicleActionSource},
                {"lane_age_ms",double(vehicle_action::age(in,"lane_age_ms"))},
                {"detection_age_ms",double(vehicle_action::age(in,"detection_age_ms"))}};
            fprintf(stderr,"[vehicle-action] %s\n",QJsonDocument(log).toJson(QJsonDocument::Compact).constData());
        }
        vehicleAction=next;aebWarning=next.cards[4].color==vehicle_action::Color::Red;
        const bool phase=status_bar::blinkPhase(now);
        const bool blinkChanged=phase!=statusBlinkPhase&&
            (changeRequest!=0||status_bar::blinkActive(next,showIntent));
        statusBlinkPhase=phase;
        return changed||blinkChanged||predictionsChanged;
    }
    void resetVehicleAction(qint64 now,const QString& source) {
        driveFeedbackControl=-1;driveFeedbackUntil=0;
        driveSelectionMade=false;laneSelectionMade=false;predictionStates.clear();pressedDrive.clear();
        drivingRequested=false;cancelLaneChange();++changeSourceEpoch_;driveWarningUntil=0;
        drivingState={};vehicleActionSource=source;updateVehicleAction(now);
    }
    bool redLightDetected() const {
        if(!recognitionRunning||!drivingState["lights_fresh"].toBool())return false;
        for(const auto& value:drivingState["light_detections"].toArray())
            if(value.toObject()["color"].toInt()==1)return true;
        return false;
    }
    void applyDriveControl(int value,bool red,qint64 now=0) {
        Q_UNUSED(red);
        if(value>=0&&value<=4){driveFeedbackControl=value;driveFeedbackUntil=0;}
        if(value==0||value==1)driveSelectionMade=true;
        if(value>=2&&value<=4)laneSelectionMade=true;
        if(value==0) {
            drivingRequested=true;driveWarningUntil=0;
        } else if(value==1){drivingRequested=false;cancelLaneChange();driveWarningUntil=0;vehicleActionEngine.stop(actionInput(now));}
        else if(value>=2&&value<=4){assumedLane=value-3;cancelLaneChange();}
        else if(value==5||value==6) {
            const int direction=value==5?-1:1;
            if(replayLaneChangePredictions)replayLaneChangePolicy.click(actionInput(now),direction);
            if(changeRequest!=direction){cancelLaneChange();changeRequest=direction;++changeSerial_;}
        }
    }
    int cpuSelecting=0,cpuCamera=0,cpuStandard=-1;
    QRectF cpuMark,cpuRoad;
    QString cpuStatus;
    QStringList availableModels;
    QSet<int> selectedModels; // Home checkbox draft; actual binding remains host-owned.
    int activeModel = -1;
    bool leftSignal = false, rightSignal = false;
    std::array<int,6> resolution{{480,480,240,240,480,480}};
    std::array<bool,6> resolutionSupported{{true,false,true,true,false,false}};
    std::array<bool,6> hd{{false,false,false,false,false,false}};
    std::array<QSet<int>,6> channelSelectedModels;

    // Optional real telemetry. Empty values render an em dash, not demo data.
    QString lane, frontDistance, rearDistance;
    QString distanceFront, distanceRear; // Runtime aliases accepted by the host.
    std::array<QString,6> frameRates;
    std::array<double,6> fps{{0,0,0,0,0,0}};
    bool hasFrame = false;
    std::array<bool,6> modelSupported{{false,false,false,false,false,false}};
    QString sensorName = QStringLiteral("OV5640");
    bool rangingSupported = true, panoramaSupported = false;
    bool lampInteractionSupported = true;
    // CSS metric correction seam: no dependency on WebEngine or QtSvg.
    struct Metrics {
        qreal rem = 16;
        qreal spacing = 4; // Tailwind --spacing; --google-spacing is not mapped.
        qreal channelHeader = 32;
        qreal sixControls = 111.5;
        qreal fourControls = 110.5;
        qreal scrollbarWidth = 15;
    } metrics;

    void setViewport(QSize size) { viewport_ = size.expandedTo(QSize(1,1)); clampScroll(); }
    QSize viewport() const { return viewport_; }
    int contentHeight() const { return int(std::ceil(layout().height)); }
    int scrollOffset() const { return offset(); }
    int maximumScroll() const { return std::max(0,contentHeight()-viewport_.height()); }
    // Positive delta moves down the document; pass -wheel.angleDelta().y().
    void scroll(int delta) {
        if (zoomCamera >= 0) return;
        if (menu_ != -2) {
            const Layout l = layout();
            const Menu m = menuLayout(l);
            if (m.maxScroll > 0) {
                menuScroll_ = std::max(0,std::min(m.maxScroll,menuScroll_+delta));
                return;
            }
        }
        offsets_[int(page)] = std::max(0,std::min(maximumScroll(),offset()+delta));
    }
    QVector<VideoTile> videoTiles() const {
        const Layout l = layout();
        QVector<VideoTile> result;
        if (zoomCamera >= 0 && (page == Page::Six || page == Page::Four)) {
            result.push_back({zoomCamera,l.zoom}); return result;
        }
        // Home 单路视图：主画面固定 C1（前视主摄像头 01）。
        // 该矩形同时用于绘制、检测叠加与命中，不另算一份。
        if (page == Page::Home) {
            if (l.homeFrame.isValid()) result.push_back({0,l.homeFrame.translated(0,-offset())});
            return result;
        }
        if (page == Page::Hdmi || (page == Page::Four && panorama)) return result;
        for (const Tile& t : l.tiles) result.push_back({t.camera,t.video.translated(0,-offset())});
        return result;
    }
    QRectF hdmiRect() const { return page == Page::Hdmi ? layout().hdmi.translated(0,-offset()) : QRectF(); }
    QRectF hdmiVideoRect() const {
        if(page!=Page::Hdmi) return {};
        const auto l=layout();
        const qreal inset=s(3);
        const qreal left=l.hdmi.left()+inset,top=l.statusBar.bottom()+inset;
        const qreal right=l.rightTop.left()-inset,bottom=l.hdmi.bottom()-inset;
        return QRectF(left,top,std::max(qreal(1),right-left),std::max(qreal(1),bottom-top)).translated(0,-offset());
    }
    QRectF localVideoRect() const {return localVideoActive?hdmiVideoRect():QRectF();}
    // Detection overlays must be clipped here; the chrome is painted afterwards.
    QRectF overlayClip() const {
        if (page == Page::Hdmi) return hdmiVideoRect().intersected(viewRect());
        const QVector<VideoTile> ts = videoTiles();
        QRectF r; for (const VideoTile& t : ts) r = r.united(t.rect);
        return r.intersected(viewRect());
    }
    QRectF panoramaRect() const {
        if (zoomCamera >= 0) return QRectF();
        if (page == Page::Four && panorama)
            return layout().panorama.translated(0,-offset());
        if (page == Page::Hdmi && hdmiPanoramaActive) {
            const QRectF v = hdmiVideoRect();
            if (v.isEmpty()) return QRectF();
            // Keep the 3:4 panorama aspect centred inside the HDMI video window.
            qreal ph = v.height(), pw = ph * 0.75;
            if (pw > v.width()) { pw = v.width(); ph = pw / 0.75; }
            return QRectF(v.center().x()-pw/2, v.center().y()-ph/2, pw, ph);
        }
        return QRectF();
    }
    QRectF controlRect(const QString& id) const {
        for (const Control& c : controls()) if (c.id == id) return c.rect;
        return QRectF();
    }
    // 按控件 id 触发，等价于鼠标点在它中心：动作合成仍只有 activate() 一处。
    Action activateControl(const QString& id) {
        const QRectF rect = controlRect(id);
        return rect.isEmpty() ? Action() : activate(rect.center().toPoint());
    }
    QRectF lanePreviewRect() const {
        if(page==Page::Hdmi)return layout().rightBottom.translated(0,-offset());
        // Home 的「感知视图」用同一份车道俯视缩略图，局部刷新也要命中它。
        if(page==Page::Home)return layout().homePreview.translated(0,-offset());
        return QRectF();
    }
    QRectF legendRect() const {
        return page==Page::Hdmi ? layout().rightTop.translated(0,-offset()) : QRectF();
    }
    QRectF drivingControlsRect() const {
        return page==Page::Hdmi ? driving_controls_panel::fitted(driving_controls_panel::artworkArea(layout().driving)).translated(0,-offset()) : QRectF();
    }
    QRectF localVideoImageRect() const {
        const QRectF window=localVideoRect();
        if(window.isEmpty())return {};
        const qreal scale=std::min(window.width()/640.,window.height()/480.);
        const QSizeF fitted(640*scale,480*scale);
        return {window.center()-QPointF(fitted.width()/2,fitted.height()/2),fitted};
    }
    Action selectLightRegion(QPointF first,QPointF last) const {
        Action action;const auto rect=localVideoImageRect();
        if(!selectingLightRegion || !localVideoActive || rect.isEmpty() ||
           !rect.contains(first) || !rect.contains(last))return action;
        const auto a=first-rect.topLeft(),b=last-rect.topLeft();
        action.kind=Action::LightRegion;action.value=2;
        action.region=QRectF(QPointF(std::min(a.x(),b.x())*640/rect.width(),80+std::min(a.y(),b.y())*480/rect.height()),
            QSizeF(std::abs(a.x()-b.x())*640/rect.width(),std::abs(a.y()-b.y())*480/rect.height()));
        if(action.region.width()<4 || action.region.height()<4)action.kind=Action::None;
        return action;
    }
    QRectF cpuImageRect() const {
        if(localVideoActive)return localVideoImageRect();
        for(const auto& tile:videoTiles())if(tile.camera==cpuCamera) {
            const double aspect=hd[size_t(cpuCamera)]?1280./720.:640./480.;
            const double width=std::min(tile.rect.width(),tile.rect.height()*aspect),height=width/aspect;
            return {tile.rect.center()-QPointF(width/2,height/2),QSizeF(width,height)};
        }
        return {};
    }
    Action selectCpuRegion(QPointF first,QPointF last) const {
        Action a;const auto image=cpuImageRect();
        if(!cpuSelecting || image.isEmpty() || !image.contains(first) || !image.contains(last))return a;
        const auto p=first-image.topLeft(),q=last-image.topLeft();
        a.kind=Action::CpuRegion;a.value=cpuSelecting;
        // Both CPU regions span the content width; dragging only sets the
        // vertical range, so a short horizontal drag still selects a strip.
        a.region=QRectF(0,std::min(p.y(),q.y())*480/image.height(),
            640,std::abs(p.y()-q.y())*480/image.height());
        if(a.region.width()<4 || a.region.height()<4)a.kind=Action::None;
        return a;
    }
    QRectF cpuPanelRect() const {return {12,70,std::min(480.,double(viewport_.width()-24)),250};}
    QRectF navPanelRect() const {return {12,70,std::min(500.,double(viewport_.width()-24)),230};}
    QRectF navImageRect() const {
        if(localVideoActive)return localVideoImageRect();
        if(page==Page::Hdmi&&navCamera==6){
            const auto window=hdmiVideoRect();const double scale=std::min(window.width()/1280.,window.height()/480.);
            const double width=1280*scale,height=480*scale;
            // Combined HDMI analytics occupies y=120..359 in 640x480.
            return {window.center().x()-width/2,window.center().y()-height,width,2*height};
        }
        for(const auto& tile:videoTiles())if(tile.camera==navCamera){
            const double aspect=hd[size_t(navCamera)]?1280./720.:640./480.;
            const double width=std::min(tile.rect.width(),tile.rect.height()*aspect),height=width/aspect;
            return {tile.rect.center()-QPointF(width/2,height/2),QSizeF(width,height)};
        }return {};
    }
    Action selectNavRegion(QPointF first,QPointF last) const {
        Action a;const auto image=navImageRect();if(!navSelecting||image.isEmpty()||!image.contains(first)||!image.contains(last))return a;
        const auto p=first-image.topLeft(),q=last-image.topLeft();
        a.region={std::min(p.x(),q.x())*640/image.width(),std::min(p.y(),q.y())*480/image.height(),std::abs(p.x()-q.x())*640/image.width(),std::abs(p.y()-q.y())*480/image.height()};
        if(a.region.width()>=24&&a.region.height()>=24)a.kind=Action::NavigationRegion;return a;
    }
    QVector<Control> navControls() const {
        if(page==Page::Home)return {};
        QVector<Control> out{{"nav-settings","导航识别",{qreal(std::max(12,viewport_.width()-155)),8,120,32},true}};
        if(navPanel&&!navSelecting){const auto r=navPanelRect();const double w=(r.width()-40)/3;
            out.push_back({"nav-source",localVideoActive?QStringLiteral("当前视频"):navCamera==6?QStringLiteral("HDMI C5/C6"):QString("C%1").arg(navCamera+1),{r.x()+10,r.y()+40,w,32},!localVideoActive});
            out.push_back({"nav-toggle",navEnabled?"关闭导航识别":"开启导航识别",{r.x()+20+w,r.y()+40,w,32},true});
            out.push_back({"nav-region","圈定导航区域",{r.x()+30+2*w,r.y()+40,w,32},!navImageRect().isEmpty()});
            out.push_back({"nav-clear","清除区域",{r.x()+10,r.y()+84,w,30},true});
            out.push_back({"nav-close","收起",{r.x()+20+w,r.y()+84,w,30},true});
        }return out;
    }
    QRectF displayPanelRect() const {
        // Home 的弹层锚在顶栏右侧按钮下方，避免盖住主画面标题。
        if(page==Page::Home)return {std::max(qreal(12),viewport_.width()-fs(450)-s(3)),fs(52),
            std::min(fs(450),qreal(viewport_.width()-24)),fs(310)};
        return {12,70,std::min(450.,double(viewport_.width()-24)),310};
    }
    QRectF displayButtonRect() const {
        return page==Page::Home?layout().homeDisplay
            :QRectF(qreal(std::max(12,viewport_.width()-425)),8,125,32);
    }
    QVector<Control> displayControls() const {
        // Home 的入口在底部工具条，由 layout() 的命中提供，不在这里重复登记。
        QVector<Control> out;
        if(page!=Page::Home)out.push_back({"display-settings","识别/显示",displayButtonRect(),true});
        if(displayPanel) {
            const auto r=displayPanelRect();const QStringList labels={recognitionRunning?"模型识别：开":"模型识别：关",
                showConfidence?"置信度显示：开":"置信度显示：关",showDistance?"距离显示：开":"距离显示：关",showIntent?"意图显示：开":"意图显示：关"};
            for(int i=0;i<4;++i)out.push_back({QString("display-toggle-%1").arg(i),labels[i],{r.x()+10,r.y()+32+i*42,r.width()-20,34},true});
            out.push_back({"display-toggle-5",showLaneOutput?"车道结果显示：开":"车道结果显示：关",{r.x()+10,r.y()+200,r.width()-20,34},true});
            out.push_back({"display-toggle-6",showObjectOutput?"11类目标结果显示：开":"11类目标结果显示：关",{r.x()+10,r.y()+242,r.width()-20,34},true});
        }return out;
    }
    QVector<Control> cpuControls() const {
        if(page==Page::Home)return {};
        QVector<Control> out{{"cpu-settings","CPU测距",{qreal(std::max(12,viewport_.width()-290)),8,120,32},true}};
        if(cpuPanel && !cpuSelecting) {
            const auto p=cpuPanelRect();const double w=(p.width()-36)/3;
            out.push_back({"cpu-source",localVideoActive?QStringLiteral("当前视频"):QString("相机 C%1").arg(cpuCamera+1),{p.x()+10,p.y()+38,w,30},!localVideoActive});
            out.push_back({"cpu-toggle",cpuEnabled?"关闭CPU测距":"开启CPU测距",{p.x()+20+w,p.y()+38,w,30},true});
            out.push_back({"cpu-close","收起",{p.x()+30+2*w,p.y()+38,w,30},true});
            out.push_back({"cpu-mark","圈定标线区",{p.x()+10,p.y()+80,w,30},!cpuImageRect().isEmpty()});
            out.push_back({"cpu-road","圈定道路区",{p.x()+20+w,p.y()+80,w,30},!cpuImageRect().isEmpty()});
            out.push_back({"cpu-clear","清除设置",{p.x()+30+2*w,p.y()+80,w,30},true});
            const QStringList standards={"2米虚线 / 4米间隔","4米虚线 / 6米间隔","6米虚线 / 9米间隔"};
            out.push_back({"cpu-standard",cpuStandard>=0&&cpuStandard<3?standards[cpuStandard]:"选择实际标线标准",{p.x()+10,p.y()+122,p.width()-20,30},true});
        }
        return out;
    }
    QVector<Control> controls() const {
        const Layout l = layout(); QVector<Control> out=cpuControls();out+=displayControls();out+=navControls();
        for (const Hit& h : l.hits) {
            QRectF r = h.rect;
            if (zoomCamera < 0) r.translate(0,-offset());
            out.push_back({h.id,h.label,r,h.enabled});
        }
        if (menu_ != -2 && zoomCamera < 0) {
            const Menu m = menuLayout(l);
            for (const Hit& h : m.hits)
                out.push_back({h.id,h.label,h.rect.intersected(m.rect),h.enabled});
        }
        return out;
    }
    void paint(QPainter& painter) const;
    void paintLanePreview(QPainter& p,const QRectF& rect,
        const QString& title=QStringLiteral("车道俯视示意")) const;
    Action activate(QPoint point);
    static bool selfTest();

private:
    struct Hit {
        QRectF rect; QString id, label;
        Action::Kind kind = Action::None;
        int camera = -1, value = 0;
        bool enabled = true;
        int internal = 0; // 1 dropdown, 2 reset, 3 back, 4 entry
    };
    struct Tile { int camera; QRectF card, title, video, resFrame, modelLabel, model; QVector<QRectF> options; };
    struct Layout {
        qreal height = 0;
        QRectF homeTitle, homeSubtitle, algorithm, algorithmTitle, algorithmSubtitle;
        QRectF model, confidenceLabel, minus, confidenceValue, plus, header, title, back, badge, panoramaButton;
        QRectF hdmi, direction, lamps, leftLamp, rightLamp, rightTop, rightBottom,driving,statusBar;
        QRectF videoSelect,videoPause,videoLoop,videoCamera,videoStatus;
        QRectF zoom, panorama, panoramaTitle, toolbar, footer, note, rangeButton, front, rear, apply, reset;
        // Home：城市道路感知主界面（顶栏 / 视图切换 / 主画面 / 统计 / 下一步行动 / 右列控制）。
        QRectF homeBar, homeBarTitle, homeSubTitle, homeView;
        QRectF homeSourceCamera, homeSourceHdmi, homeDisplay;
        QRectF homeViewSingle, homeViewFour, homeViewSix, homeViewSpace;
        QRectF homeVideo, homeVideoTitle, homeVideoMeta, homeFrame;
        QRectF homeLight, homeStats;
        QRectF homePredict, homePredictTitle, homePredictState, homePredictCar, homePredictCaption;
        std::array<QRectF,6> homePredictRings, homePredictTags;
        QRectF homeDrive, homeDriveTitle, homeLane, homeLaneTitle, homeChange, homeChangeTitle, homePreview;
        std::array<QRectF,7> homeRings;
        std::array<QRectF,2> homeDriveTags, homeChangeTags;
        std::array<QRectF,3> homeLaneTags;
        QRectF homeTools, homeGear, homeModel, homeLegendButton;
        QVector<QRectF> entries;
        QVector<Tile> tiles;
        QVector<Hit> hits;
    };
    struct Menu { QRectF rect; QVector<Hit> hits; int maxScroll = 0; };
    QSize viewport_{1280,720};
    std::array<int,4> offsets_{{0,0,0,0}};
    int menu_ = -2; // -2 closed, -1 Home, 0..5 channel
    int menuScroll_ = 0;
    Page menuPage_ = Page::Home;
    qreal s(qreal units) const { return metrics.spacing*units; }
    qreal fs(qreal px) const { return px*metrics.rem/16; }
    QRectF viewRect() const { return QRectF(QPointF(),QSizeF(viewport_)); }
    int offset() const { return std::max(0,std::min(offsets_[int(page)],std::max(0,int(std::ceil(layout().height))-viewport_.height()))); }
    void clampScroll() { offsets_[int(page)] = offset(); }
    Layout layout() const {
        Layout l=layoutForWidth(viewport_.width());
        if(zoomCamera<0 && l.height>viewport_.height()+.01 && metrics.scrollbarWidth>0)
            l=layoutForWidth(std::max(qreal(1),viewport_.width()-metrics.scrollbarWidth));
        return l;
    }
    Layout layoutForWidth(qreal width) const;
    Menu menuLayout(const Layout&) const;
    static QColor ink() { return QColor("#0e1115"); }
    static QColor muted() { return QColor("#7f8d9f"); }
    static QColor blue() { return QColor("#4285f4"); }
    static QColor border() { return QColor("#ebebeb"); }
    static QColor secondary() { return QColor("#dbeafe"); }
    static QString dash() { return QString(QChar(0x2014)); }
    static QString resName(int r) { return r == 240 ? QStringLiteral("320×240") : QString::number(r)+QStringLiteral("p"); }
    QString cameraName(int c) const {
        static const char* six[] = {"前视","前视","左视","右视","后视","后视"};
        static const char* four[] = {"正面","","侧面","背面","顶视",""};
        return c >= 0 && c < 6 ? QString::fromUtf8(page == Page::Four ? four[c] : six[c]) : QString();
    }
    QString channelLabel(int camera) const {
        if(page==Page::Four) {
            const int cameras[4]={0,4,2,3};
            for(int i=0;i<4;++i)if(cameras[i]==camera)
                return QStringLiteral("CH%1").arg(i+1,2,10,QChar('0'));
        }
        return QStringLiteral("CH%1").arg(camera+1);
    }
    static QFont font(qreal px, int weight=QFont::Medium) {
        QFont f; f.setFamily(QStringLiteral("Segoe UI"));
        f.setPixelSize(std::max(1,int(std::round(px)))); f.setWeight(weight==600?QFont::DemiBold:weight); return f;
    }
    static bool rangingLocked(int c) { return c==0||c==1||c==4||c==5; }
    static int validSelectionCount(const QSet<int>& selected,int available) {
        int count=0;for(int i:selected)if(i>=0&&i<available)++count;return count;
    }
    QString zoomInfo(int camera) const;
    // Home 深色主题（设计稿第 1 页「城市道路感知」）。只用于 Home 页，
    // 不影响已确认的其他页面配色与控件。
    static QColor homeBg() { return QColor("#0a131a"); }
    static QColor homePanel() { return QColor("#0c1821"); }
    static QColor homeLine() { return QColor("#233f49"); }
    static QColor homeInk() { return QColor("#e2f0f2"); }
    static QColor homeDim() { return QColor("#7d94a1"); }
    static QColor homeAccent() { return QColor("#44d8c3"); }
    void homeCard(QPainter& p,const QRectF& r,const QRectF& title,const QString& label) const;
    void homeChip(QPainter& p,const QRectF& r,const QString& label,bool active,bool enabled=true) const;
    void homeTab(QPainter& p,const QRectF& r,const QString& label,const QString& glyph,bool active,bool enabled=true) const;
    // Home 图形：车身/播放/停止/违规/告警自绘，箭头复用 icon()。
    void homeGlyph(QPainter& p,const QRectF& r,const QString& name,const QColor& color) const;
    QString videoMetaText() const;
    QString vehicleActionStateText() const;
    vehicle_action::Color predictColor(int ring,bool parked) const;
    int homeLightCode() const;
    QString homeLightText() const;
    QColor homeLightColor() const;
    QString homeLightPermissionText() const;
    QRectF legendOverlayRect() const;
    qreal textWidth(const QString& t, qreal px) const {
        // Stable CSS advance measurements for fixed prototype controls. Text itself
        // remains native/shaped and elided using the target system font.
        if(px==12 && (t=="480p"||t=="720p"))return fs(28.78125);
        if(px==12 && t==QStringLiteral("320×240"))return fs(51.125);
        if(px==12 && (t==QStringLiteral("4 路已配置")||t==QStringLiteral("6 路已配置")))return fs(58.59375);
        bool cjk=!t.isEmpty();for(QChar ch:t)if(ch.unicode()<0x3000)cjk=false;
        if(cjk)return t.size()*fs(px);
        return QFontMetricsF(font(fs(px))).horizontalAdvance(t);
    }
    QString homeModelSummary() const {
        int count=0,index=-1;for(int i:selectedModels)if(i>=0&&i<availableModels.size()){++count;index=i;}
        if(count==0)return QStringLiteral("未选择模型");
        if(count==1)return availableModels[index];
        return QStringLiteral("已选 %1 个模型").arg(count);
    }
    QString channelModelSummary(int camera) const {
        const QSet<int>& selected=channelSelectedModels[camera];
        const int count=validSelectionCount(selected,availableModels.size());
        if(count==0)return QStringLiteral("未选择");
        if(count==1){const int index=*selected.constBegin();return index>=0&&index<availableModels.size()?availableModels[index]:QStringLiteral("未选择");}
        return QStringLiteral("已选 %1 个").arg(count);
    }
    QString rateLabel(int c) const {
        if(!frameRates[c].isEmpty())return frameRates[c];
        return fps[c]>0?QString::number(fps[c],'f',fps[c]>=10?0:1)+QStringLiteral("fps"):dash();
    }
    void text(QPainter& p, QRectF r, const QString& t, qreal px=14, QColor color=ink(), int weight=QFont::Medium,
              int align=Qt::AlignLeft|Qt::AlignVCenter) const {
        if (r.width() <= 0 || r.height() <= 0) return;
        p.save(); p.setFont(font(fs(px),weight)); p.setPen(color);
        p.drawText(r,align|Qt::TextSingleLine,QFontMetricsF(p.font()).elidedText(t,Qt::ElideRight,std::max(qreal(0),r.width())));
        p.restore();
    }
    void heading(QPainter& p,QRectF r,const QString& t,qreal px) const {
        if(r.width()<=0||r.height()<=0)return;
        p.save();QFont f=font(fs(px),600);f.setLetterSpacing(QFont::AbsoluteSpacing,fs(-.025*px));p.setFont(f);p.setPen(ink());
        p.drawText(r,Qt::AlignLeft|Qt::AlignVCenter|Qt::TextSingleLine,QFontMetricsF(f).elidedText(t,Qt::ElideRight,r.width()));p.restore();
    }
    static void box(QPainter& p,QRectF r,QColor fill=Qt::white,QColor stroke=border(),qreal radius=8,qreal width=.75) {
        if (r.isEmpty()) return;
        p.save(); p.setPen(stroke.alpha() ? QPen(stroke,width) : QPen(Qt::NoPen)); p.setBrush(fill);
        p.drawRoundedRect(r.adjusted(width/2,width/2,-width/2,-width/2),radius,radius); p.restore();
    }
    static void icon(QPainter& p,QRectF r,const QString& name,QColor color=blue());
    void button(QPainter& p,QRectF r,const QString& label,const QString& glyph=QString(),bool selected=false,bool enabled=true,bool primary=false,QColor iconColor=blue()) const {
        if (r.isEmpty()) return;
        p.save(); if (!enabled) p.setOpacity(.5);
        box(p,r,primary ? blue() : selected ? secondary() : QColor(Qt::white),primary ? QColor(Qt::transparent) : selected ? blue() : border());
        const qreal iconSize=std::min(s(4),r.height()*.55);
        if (!glyph.isEmpty()) icon(p,QRectF(r.x()+s(2),r.center().y()-iconSize/2,iconSize,iconSize),glyph,primary ? QColor(Qt::white) : iconColor);
        text(p,r.adjusted(glyph.isEmpty()?s(2):s(2)+iconSize+s(1),0,-s(2),0),label,std::min(qreal(14),r.height()*.5),primary?QColor(Qt::white):selected?QColor("#003e8f"):ink(),QFont::Medium,
             glyph.isEmpty()?Qt::AlignCenter:Qt::AlignLeft|Qt::AlignVCenter);
        p.restore();
    }
};

inline Frontend::Layout Frontend::layoutForWidth(qreal width) const {
    Layout l; const qreal w=width,h=viewport_.height(); const bool sm=viewport_.width()>=640,lg=viewport_.width()>=1024;
    auto hit=[&](QRectF r,QString id,QString label,Action::Kind kind,int camera=-1,int value=0,bool enabled=true,int internal=0) {
        Hit a; a.rect=r;a.id=id;a.label=label;a.kind=kind;a.camera=camera;a.value=value;a.enabled=enabled;a.internal=internal;l.hits.push_back(a);
    };
    if (page==Page::Home) {
        // 深色「城市道路感知」主界面（设计稿第 1 页）。左列：主画面 + 统计条 + 下一步行动 + 工具条；
        // 右列：行驶控制 / 假定车道选择 / 变道控制 / 感知视图。所有可点区域都来自下面的同一份矩形。
        const qreal pad=sm?s(3):s(2);
        const qreal barH=std::max(fs(46),h*.05);
        const qreal subH=std::max(fs(30),h*.036);
        const qreal footH=fs(18);
        l.homeBar={0,0,w,barH};
        const qreal srcH=std::max(fs(24),std::min(fs(32),barH-fs(12)));
        const qreal srcY=(barH-srcH)/2;
        const QString srcLabels[2]={QStringLiteral("OV5640 输入"),QStringLiteral("HDMI 输入")};
        const qreal srcIcon=fs(15);
        const qreal src0W=textWidth(srcLabels[0],12)+srcIcon+s(4)+s(7);
        const qreal src1W=textWidth(srcLabels[1],12)+srcIcon+s(4)+s(7);
        l.homeSourceHdmi={w-pad-src1W,srcY,src1W,srcH};
        l.homeSourceCamera={l.homeSourceHdmi.left()-s(2)-src0W,srcY,src0W,srcH};
        l.homeBarTitle={pad,0,std::max(fs(120),l.homeSourceCamera.left()-pad-s(3)),barH};
        l.homeSubTitle={pad,barH+s(1),textWidth(QStringLiteral("城市道路感知"),18)+s(3),subH};
        // 视图切换右对齐；六路是既有页面，作为第四个入口保留，不改变导航结构。
        const QString viewLabels[4]={QStringLiteral("单路视图"),QStringLiteral("四路视图"),
            QStringLiteral("六路视图"),QStringLiteral("空间视图")};
        const qreal viewY=barH+s(1),viewH=subH-s(1);
        qreal viewRight=w-pad;
        for(int i=3;i>=0;--i) {
            const qreal vw=textWidth(viewLabels[i],12)+fs(15)+s(4)+s(9);
            const QRectF r(viewRight-vw,viewY,vw,viewH);
            if(i==0)l.homeViewSingle=r;else if(i==1)l.homeViewFour=r;
            else if(i==2)l.homeViewSix=r;else l.homeViewSpace=r;
            viewRight=r.left()-s(1.5);
        }
        l.homeView={l.homeViewSingle.left(),viewY,w-pad-l.homeViewSingle.left(),viewH};
        const qreal top=l.homeSubTitle.bottom()+pad;
        const qreal bottom=std::max(top+fs(220),h-pad-footH-s(3));
        const qreal contentH=bottom-top;
        const qreal rightW=std::min(std::max(w*.255,fs(280)),std::max(fs(280),w*.34));
        const qreal leftW=std::max(fs(360),w-2*pad-rightW-s(3));
        const qreal gap=s(3);
        const qreal statsH=std::max(fs(36),contentH*.052);
        const qreal predictH=std::max(fs(124),contentH*.2);
        const qreal videoH=std::max(fs(150),contentH-statsH-predictH-2*gap);
        l.homeVideo={pad,top,leftW,videoH};
        // 卡头 + 画面槽；画面按真实源宽高比居中，避免横竖屏出现亮色留边。
        const qreal vHead=std::max(fs(24),std::min(fs(34),videoH*.08));
        l.homeVideoTitle={pad+fs(8),top+1,leftW*.55,vHead};
        l.homeVideoMeta={pad+leftW*.5,top+1,leftW*.5-fs(8),vHead};
        const QRectF slot(pad+1,top+1+vHead,std::max(qreal(1),leftW-2),std::max(fs(40),videoH-2-vHead));
        const qreal aspect=hd[0]?16./9.:4./3.;
        qreal fw=slot.width(),fh=fw/aspect;
        if(fh>slot.height()){fh=slot.height();fw=fh*aspect;}
        l.homeFrame=QRectF(slot.center()-QPointF(fw/2,fh/2),QSizeF(std::max(qreal(1),fw),std::max(qreal(1),fh)));
        const qreal lightW=std::min(fs(196),l.homeFrame.width()*.3),lightH=fs(92);
        l.homeLight={l.homeFrame.left()+s(2),l.homeFrame.top()+s(2),
            std::max(fs(120),lightW),std::min(lightH,std::max(fs(36),l.homeFrame.height()-s(4)))};
        l.homeStats={pad,l.homeVideo.bottom()+gap,leftW,statsH};
        l.homePredict={pad,l.homeStats.bottom()+gap,leftW,predictH};
        // 设计稿没有独立工具条：检测模型/置信度/识别对照/识别显示与视图切换同一行，右对齐到视图组左侧。
        // 下一步行动：左侧车图标 + 6 个圆环（左转/直行/停止/右转/违规/急停）。
        const qreal pTitle=std::max(fs(20),predictH*.14);
        const qreal carW=std::min(fs(230),leftW*.2);
        const qreal tagH=fs(16);
        l.homePredictTitle={pad+s(4),l.homePredict.top(),leftW*.45,pTitle};
        l.homePredictState={pad+leftW*.5,l.homePredict.top(),leftW*.5-s(3),pTitle};
        const qreal carDia=std::max(fs(36),std::min(std::max(fs(20),predictH-pTitle-tagH-s(2)),fs(112)));
        l.homePredictCar={pad+s(4),l.homePredict.top()+pTitle+s(1),carDia,carDia};
        l.homePredictCaption={l.homePredictCar.right()+s(3),l.homePredictCar.top(),
            std::max(fs(40),pad+carW-(l.homePredictCar.right()+s(3))),carDia};
        const qreal ringX=pad+carW,ringW=std::max(fs(90),leftW-carW-s(2));
        const qreal ringTop=l.homePredict.top()+pTitle+s(1);
        const qreal cellW=ringW/6;
        const qreal ringH=std::max(fs(20),predictH-pTitle-tagH-s(7));
        const qreal dia=std::max(fs(18),std::min(ringH,cellW-s(2)));
        for(int i=0;i<6;++i) {
            const qreal cx=ringX+cellW*(i+.5);
            l.homePredictRings[size_t(i)]={cx-dia/2,ringTop,dia,dia};
            l.homePredictTags[size_t(i)]={cx-cellW/2,ringTop+dia+s(1),cellW,tagH};
        }
        const qreal rx=w-pad-rightW;
        const qreal driveH=contentH*.235,laneH=contentH*.285,changeH=contentH*.15;
        const qreal previewH=std::max(fs(90),contentH-driveH-laneH-changeH-3*gap);
        l.homeDrive={rx,top,rightW,driveH};
        l.homeLane={rx,l.homeDrive.bottom()+gap,rightW,laneH};
        l.homeChange={rx,l.homeLane.bottom()+gap,rightW,changeH};
        l.homePreview={rx,l.homeChange.bottom()+gap,rightW,previewH};
        const qreal cardTitle=std::max(fs(20),driveH*.14);
        l.homeDriveTitle={rx+s(2),l.homeDrive.top(),rightW-s(4),cardTitle};
        l.homeLaneTitle={rx+s(2),l.homeLane.top(),rightW-s(4),std::max(fs(20),laneH*.12)};
        l.homeChangeTitle={rx+s(2),l.homeChange.top(),rightW-s(4),std::max(fs(18),changeH*.2)};
        const qreal driveCell=(rightW-s(4))/2,driveTag=fs(32);
        // 圆环直径不超过卡片高度的 62%，与设计稿留白一致（原来顶满整卡更"挤"）。
        const qreal driveDia=std::max(fs(20),std::min({driveCell-s(8),driveH*.55,
            driveH-cardTitle-s(2)-driveTag-s(2)}));
        for(int i=0;i<2;++i) {
            const qreal driveCell2=(rightW-s(4))/2;
            const qreal areaTop=l.homeDrive.top()+cardTitle+s(2);
            const qreal areaBottom=l.homeDrive.bottom()-s(2);
            const qreal blockH=driveDia+driveTag+s(1);
            const qreal cy=areaTop+std::max(qreal(0),(areaBottom-areaTop-blockH)/2)+driveDia/2;
            const qreal cx=rx+s(2)+driveCell2*(i+.5);
            l.homeRings[size_t(i)]={cx-driveDia/2,cy-driveDia/2,driveDia,driveDia};
            l.homeDriveTags[size_t(i)]={rx+s(2)+driveCell2*i+s(1),cy+driveDia/2+s(1),driveCell2-s(2),driveTag};
        }
        const qreal laneCell=(rightW-s(4))/3,laneTag=fs(34);
        const qreal laneDia=std::max(fs(18),std::min({laneCell-s(6),laneH*.50,
            laneH-l.homeLaneTitle.height()-s(2)-laneTag-s(2)}));
        for(int i=0;i<3;++i) {
            const qreal areaTop=l.homeLane.top()+l.homeLaneTitle.height()+s(2);
            const qreal areaBottom=l.homeLane.bottom()-s(2);
            const qreal blockH=laneDia+laneTag+s(1);
            const qreal cy=areaTop+std::max(qreal(0),(areaBottom-areaTop-blockH)/2)+laneDia/2;
            const qreal cx=rx+s(2)+laneCell*(i+.5);
            l.homeRings[size_t(i+2)]={cx-laneDia/2,cy-laneDia/2,laneDia,laneDia};
            l.homeLaneTags[size_t(i)]={rx+s(2)+laneCell*i+s(1),cy+laneDia/2+s(1),laneCell-s(2),laneTag};
        }
        const qreal changeTop=l.homeChange.top()+l.homeChangeTitle.height()+s(2);
        const qreal changeW=(rightW-s(4)-s(2))/2;
        const qreal changeH2=std::max(fs(24),l.homeChange.bottom()-s(2)-changeTop);
        l.homeRings[5]={rx+s(2),changeTop,changeW,changeH2};
        l.homeRings[6]={l.homeRings[5].right()+s(2),changeTop,changeW,changeH2};
        l.homeChangeTags[0]=l.homeRings[5];
        l.homeChangeTags[1]=l.homeRings[6];
        // 设计稿次行只有「城市道路感知 + 视图切换」：检测模型/置信度/识别对照/识别显示
        // 收进顶栏「识别设置」弹层，控件 id、快捷键与作用保持不变。
        const qreal gearW=srcH;
        l.homeGear={l.homeSourceCamera.left()-s(3)-gearW,srcY,gearW,srcH};
        if(homeToolsPanel) {
            const qreal panelW=fs(240),rowH=fs(30);
            const qreal px=std::min(w-pad-panelW,l.homeSourceHdmi.right()-panelW);
            const qreal py=barH+s(2);
            l.homeTools={px,py,panelW,rowH*4+s(6)};
            l.homeModel={px+s(3),py+s(3),panelW-s(6),rowH-s(2)};
            l.model=l.homeModel;
            const qreal row1=l.homeModel.bottom()+s(1);
            const qreal minusW=fs(24),valueW=fs(44);
            const qreal confLabelW=textWidth(QStringLiteral("置信度"),11)+s(2);
            l.confidenceLabel={px+s(3),row1,confLabelW,rowH-s(2)};
            l.minus={l.confidenceLabel.right(),row1,minusW,rowH-s(2)};
            l.confidenceValue={l.minus.right()+s(.5),row1,valueW,rowH-s(2)};
            l.plus={l.confidenceValue.right()+s(.5),row1,minusW,rowH-s(2)};
            const qreal row2=row1+rowH;
            l.homeLegendButton={px+s(3),row2,panelW-s(6),rowH-s(2)};
            l.homeDisplay={px+s(3),row2+rowH,panelW-s(6),rowH-s(2)};
        }
        l.footer={pad,l.homePredict.bottom(),w-2*pad,footH};
        l.height=std::max(h,l.footer.bottom()+pad);
        hit(l.model,QStringLiteral("model-dropdown-btn"),QStringLiteral("检测模型"),Action::None,-1,0,true,1);
        hit(l.minus,QStringLiteral("conf-minus"),QStringLiteral("降低置信度"),Action::Confidence,-1,-5,confidence>.1001);
        hit(l.plus,QStringLiteral("conf-plus"),QStringLiteral("提高置信度"),Action::Confidence,-1,5,confidence<.8999);
        hit(l.homeLegendButton,QStringLiteral("home-legend"),QStringLiteral("识别对照"),Action::None,-1,0,true,5);
        hit(l.homeDisplay,QStringLiteral("display-settings"),QStringLiteral("识别/显示"),Action::ViewerControl,-1,4);
        hit(l.homeSourceCamera,QStringLiteral("home-source-camera"),srcLabels[0],Action::Navigate,-1,int(Page::Home),true,4);
        hit(l.homeSourceHdmi,QStringLiteral("home-source-hdmi"),srcLabels[1],Action::Navigate,-1,int(Page::Hdmi),true,4);
        hit(l.homeGear,QStringLiteral("home-tools"),QStringLiteral("识别设置"),Action::None,-1,0,true,7);
        hit(l.homeViewSingle,QStringLiteral("home-view-single"),viewLabels[0],Action::Navigate,-1,int(Page::Home),true,4);
        hit(l.homeViewFour,QStringLiteral("home-view-four"),viewLabels[1],Action::Navigate,-1,int(Page::Four),true,4);
        hit(l.homeViewSix,QStringLiteral("home-view-six"),viewLabels[2],Action::Navigate,-1,int(Page::Six),true,4);
        hit(l.homeViewSpace,QStringLiteral("home-view-space"),viewLabels[3],Action::Panorama,-1,1,panoramaSupported);
        // 七个驾驶控制沿用既有控件 id，快捷键与 main 的动作分发不变。
        for(int i=0;i<7;++i) {
            const QString id=QStringList{QStringLiteral("drive-go"),QStringLiteral("drive-stop"),
                QStringLiteral("drive-lane-0"),QStringLiteral("drive-lane-1"),QStringLiteral("drive-lane-2"),
                QStringLiteral("drive-change-left"),QStringLiteral("drive-change-right")}[i];
            const QString label=QStringList{QStringLiteral("行驶"),QStringLiteral("停止"),
                QStringLiteral("左转车道"),QStringLiteral("直行车道"),QStringLiteral("右转车道"),
                QStringLiteral("向左变道"),QStringLiteral("向右变道")}[i];
            hit(l.homeRings[size_t(i)],id,label,Action::DriveControl,-1,i);
        }
        return l;
    }
    const bool zoom=zoomCamera>=0 && (page==Page::Six||page==Page::Four);
    const qreal px=zoom?(sm?s(4):s(3)):page==Page::Hdmi?(sm?s(5):s(3)):s(2);
    const qreal py=zoom?(sm?s(4):s(3)):page==Page::Hdmi?(sm?s(4):s(3)):s(2);
    const qreal cw=std::max(qreal(1),w-2*px),bh=page==Page::Hdmi?fs(38):fs(34);
    const qreal bw=2+s(6)+s(4)+s(2)+textWidth(QStringLiteral("返回"),14);
    l.back={px,py,bw,bh};l.header={px,py,cw,bh};
    hit(l.back,zoom?"zoom-back":"back-home",QStringLiteral("返回"),zoom?Action::Zoom:Action::Navigate,-1,-1,true,3);
    l.title={l.back.right()+(page==Page::Hdmi?(sm?s(5):s(4)):s(3)),py,cw-bw-s(3),bh};
    if (zoom) {
        l.zoom={px,l.back.bottom()+s(3),cw,std::max(qreal(1),h-py-l.back.bottom()-s(3))};
        l.height=h;return l;
    }
    if (page==Page::Hdmi) {
        const qreal controlY=l.header.bottom()+s(2), controlH=fs(34),gap=s(2);
        const qreal buttonW=std::min(fs(108),cw/7),statusW=std::min(fs(180),cw*.20);
        const qreal selectW=std::max(qreal(60),cw-4*buttonW-5*gap-statusW);
        l.videoSelect={px,controlY,selectW,controlH};
        l.panoramaButton={l.videoSelect.right()+gap,controlY,buttonW,controlH};
        l.videoStatus={l.panoramaButton.right()+gap,controlY,statusW,controlH};
        l.videoPause={l.videoStatus.right()+gap,controlY,buttonW,controlH};
        l.videoLoop={l.videoPause.right()+gap,controlY,buttonW,controlH};
        l.videoCamera={l.videoLoop.right()+gap,controlY,buttonW,controlH};
        hit(l.panoramaButton,"hdmi-panorama",QStringLiteral("全景融合"),Action::HdmiPanorama,-1,hdmiPanoramaActive?0:1,true,1);
        const qreal vy=l.videoSelect.bottom()+s(2),vh=std::max(fs(160),h-vy-py-s(2)-fs(16));
        l.hdmi={px,vy,cw,vh};
        // Absolute positions are relative to the video's padding box, inside its 1px border.
        const qreal vt=l.hdmi.y()+1;
        const qreal tagWidth=std::min(fs(340),std::max(fs(260),cw*.19));
        const qreal rx=l.hdmi.right()-1-s(2)-tagWidth,ry=vt+s(2),rh=l.hdmi.height()-2-s(4);
        const qreal statusWidth=rx-(l.hdmi.x()+s(3))-s(2);
        l.statusBar={l.hdmi.x()+s(3),ry,statusWidth,statusWidth*status_bar::panelHeight/status_bar::panelWidth};
        const qreal previewHeight=std::min(rh*.18,fs(100));
        const qreal controlsHeight=tagWidth/3+fs(252);
        const qreal legendHeight=std::min(fs(260),std::max(fs(112),rh-previewHeight-controlsHeight-s(4)));
        l.rightTop={rx,ry,tagWidth,legendHeight};
        l.rightBottom={rx,ry+rh-previewHeight,tagWidth,previewHeight};
        l.driving={rx,l.rightTop.bottom()+s(2),tagWidth,
            std::max(qreal(0),l.rightBottom.top()-l.rightTop.bottom()-s(4))};
        l.direction={};l.lamps={};l.leftLamp={};l.rightLamp={};
        const auto cr=l.driving;
        const auto artwork=driving_controls_panel::artworkArea(cr);
        for(int value=0;value<7;++value){
                const QString id=QStringList{"drive-go","drive-stop","drive-lane-0","drive-lane-1","drive-lane-2","drive-change-left","drive-change-right"}[value];
                const QString label=QStringList{"行驶","停止","左转车道","直行车道","右转车道","向左变道","向右变道"}[value];
                hit(driving_controls_panel::mapControl(artwork,value),id,label,Action::DriveControl,-1,value);
        }
        const double settingsY=cr.bottom()-driving_controls_panel::toolsHeight;
        if(cr.height()>driving_controls_panel::toolsHeight) {
            hit({cr.x()+fs(6),settingsY,cr.width()*.45,24},"rule-light-count",expectedLightGroups?QString("灯组：%1").arg(expectedLightGroups):QStringLiteral("灯组：未确认"),Action::LightCount);
            hit({cr.x()+cr.width()*.48,settingsY,cr.width()*.29,24},"rule-light-region","设灯区",Action::LightRegion,-1,1,localVideoActive);
            hit({cr.x()+cr.width()*.79,settingsY,cr.width()*.19,24},"rule-light-clear","清除",Action::LightRegion,-1,0,!aheadLightRegion.isEmpty());
        }
        l.footer={px,l.hdmi.bottom()+s(2),cw,fs(16)};
        l.height=std::max(h,l.footer.bottom()+py);return l;
    }
    const bool four=page==Page::Four, pano=four&&panorama;
    const QString badge=four?QStringLiteral("4 路已配置"):QStringLiteral("6 路已配置");
    const qreal badgeW=textWidth(badge,12)+s(6);
    l.badge={w-px-badgeW,py+(bh-fs(24))/2,badgeW,fs(24)};
    if(four) {
        const qreal pbw=s(6)+s(4)+s(2)+textWidth(QStringLiteral("全景融合"),14)+2;
        l.panoramaButton={l.badge.x()-s(3)-pbw,py,pbw,bh};
        hit(l.panoramaButton,"toggle-panorama",QStringLiteral("全景融合"),Action::Panorama,-1,panorama?0:1,panoramaSupported);
        l.title.setRight(l.panoramaButton.x()-s(3));
    } else l.title.setRight(l.badge.x()-s(3));
    const qreal top=l.header.bottom()+s(2);
    // Keep all camera-page actions on one row so video tiles get the saved height.
    const qreal gap=s(2);
    const qreal pad=s(2),innerX=px+1+pad,innerW=cw-2-2*pad;
    const qreal rangeW=s(4)+s(3)+s(2)+textWidth(QStringLiteral("开启测距"),12)+2;
    const qreal distanceW=fs(230);
    const qreal applyW=textWidth(QStringLiteral("应用配置"),12)+s(5),resetW=textWidth(QStringLiteral("恢复默认"),12)+s(5);
    const QString note=ranging?QStringLiteral("测距已开启，前后视分辨率锁定480p"):QStringLiteral("分辨率选择将在应用后生效");
    const qreal noteW=textWidth(note,12);
    const qreal toolbarScale=std::min(qreal(1),(innerW-gap*5)/(rangeW+distanceW*2+applyW+resetW+noteW));
    const qreal toolbarH=2+2*pad+fs(34)*toolbarScale;
    if(!pano) {
        const auto item=[&](qreal x,qreal width,qreal height) {
            return QRectF(x,pad+(fs(34)*toolbarScale-height*toolbarScale)/2,width*toolbarScale,height*toolbarScale);
        };
        qreal x=innerX;
        auto next=[&](qreal width) { const qreal left=x;x+=width*toolbarScale+gap;return left; };
        if(!four)l.rangeButton=item(next(rangeW),rangeW,34);
        l.front=item(next(distanceW),distanceW,34);
        l.rear=item(next(distanceW),distanceW,34);
        if(four)l.rangeButton=item(next(rangeW),rangeW,34);
        l.apply=item(next(applyW),applyW,32);
        l.reset=item(next(resetW),resetW,34);
        l.note=item(next(noteW),noteW,20);
    }
    const qreal bottomH=s(2)+toolbarH+s(2)+fs(16)+py;
    qreal end=top;
    if(pano) {
        l.panoramaTitle={px,top+s(3),cw,fs(20)};
        l.panorama={px,l.panoramaTitle.bottom()+s(2),cw,cw*9/16};end=l.panorama.bottom();
    } else {
        const int count=four?4:6,cols=four?(sm?2:1):(lg?3:2),rows=(count+cols-1)/cols;
        const qreal tileGap=s(1);
        const qreal tw=(cw-tileGap*(cols-1))/cols;
        const qreal available=h-top-bottomH-tileGap*(rows-1);
        const qreal th=available/rows;
        const int cameras[6]={0,4,2,3,0,0};
        for(int i=0;i<count;++i) {
            const int c=four?cameras[i]:i;
            Tile t;t.camera=c;t.card={px+(i%cols)*(tw+tileGap),top+(i/cols)*(th+tileGap),tw,th};
            const qreal titleH=std::min(fs(28),std::max(fs(20),th*.08));
            t.title={t.card.x()+1,t.card.y()+1,tw-2,titleH};
            const bool fixed=c==1||c==5;
            const qreal controlH=std::min(fs(30),std::max(fs(20),th-2-titleH-fs(16)));
            const qreal scale=controlH/fs(30);
            const qreal rx=t.card.x()+1+s(1),right=t.card.right()-1-s(1),rw=right-rx;
            const qreal rowY=t.card.bottom()-1-s(1)-controlH;
            const QVector<int> values=(c==2||c==3)?QVector<int>{240,480,720}:QVector<int>{480,720};
            const qreal labelW=textWidth(QStringLiteral("模型"),10)*scale;
            const qreal optionGap=s(1)*scale,innerGap=s(1.5)*scale;
            qreal resW=0;
            QVector<qreal> optionWidths;
            if(fixed) {
                resW=(textWidth(QStringLiteral("480p"),12)+s(4)+s(2)+textWidth(QStringLiteral("固定分辨率"),12))*scale;
            } else {
                for(int value:values) optionWidths.push_back((textWidth(resName(value),12)+s(4))*scale);
                resW=2+2*optionGap;
                for(qreal width:optionWidths)resW+=width;
            }
            const qreal minModelW=fs(72)*scale;
            const qreal maxResW=rw-labelW-2*innerGap-minModelW;
            resW=std::max(qreal(0),std::min(resW,maxResW));
            t.resFrame={rx,rowY,resW,controlH};
            if(!fixed) {
                qreal ox=rx+1+optionGap;
                for(int i=0;i<values.size();++i) {
                    const qreal ow=std::min(optionWidths[i],std::max(qreal(1),t.resFrame.right()-ox-optionGap));
                    QRectF r(ox,rowY+1+(controlH-2-fs(24)*scale)/2,ow,fs(24)*scale);t.options.push_back(r);
                    const bool unlocked=resolutionSupported[c]&&!(ranging&&rangingLocked(c));
                    hit(r,QStringLiteral("res-ch%1-%2").arg(c+1).arg(values[i]),resName(values[i]),Action::Resolution,c,values[i],unlocked);
                    ox+=ow+optionGap;
                }
            }
            const qreal labelX=t.resFrame.right()+innerGap;
            t.modelLabel={labelX,rowY,labelW,controlH};
            const qreal modelX=labelX+labelW+innerGap;
            t.model={modelX,rowY,std::max(qreal(1),right-modelX),controlH};
            t.video={t.card.x()+1,t.title.bottom(),tw-2,rowY-t.title.bottom()};
            hit(t.model,QStringLiteral("model-ch%1").arg(c+1),QStringLiteral("模型"),Action::None,c,0,true,1);
            hit(four?t.video:t.card,QStringLiteral("zoom-ch%1").arg(c+1),QStringLiteral("放大 ")+channelLabel(c)+QStringLiteral(" ")+cameraName(c),Action::Zoom,c,c);
            l.tiles.push_back(t);
        }
        end=top+rows*th+(rows-1)*tileGap;
    }
    const qreal barY=std::max(end+s(2),h-bottomH+s(2));
    l.toolbar={px,barY,cw,toolbarH};
    for(QRectF* r:{&l.rangeButton,&l.front,&l.rear,&l.apply,&l.reset,&l.note})
        if(!r->isEmpty())r->moveCenter(QPointF(r->center().x(),l.toolbar.center().y()));
    hit(l.apply,"apply-config",QStringLiteral("应用配置"),Action::Apply);
    hit(l.reset,"reset-res",QStringLiteral("恢复默认"),Action::None,-1,0,true,2);
    if(!pano)hit(l.rangeButton,"toggle-ranging",ranging?QStringLiteral("关闭测距"):QStringLiteral("开启测距"),Action::Ranging,-1,ranging?0:1,rangingSupported);
    l.footer={px,l.toolbar.bottom()+s(2),cw,fs(16)};
    l.height=std::max(h,l.footer.bottom()+py);return l;
}

inline Frontend::Menu Frontend::menuLayout(const Layout& l) const {
    Menu m;if(menu_==-2||menuPage_!=page)return m;
    QRectF anchor;
    if(menu_==-1&&page==Page::Home)anchor=l.model;
    else if(menu_==-3&&page==Page::Hdmi)anchor=l.videoSelect;
    else for(const Tile& t:l.tiles)if(t.camera==menu_)anchor=t.model;
    if(anchor.isEmpty())return m;
    anchor.translate(0,-offset());
    if(!anchor.intersects(QRectF(QPointF(),QSizeF(viewport_))))return m;
    const bool home=menu_==-1;const qreal pad=home?s(2):s(1.5),row=home?fs(32):fs(24.5);
    const bool video=menu_==-3;
    const int count=video?std::max(1,localVideos.size()):4+availableModels.size();
    const qreal mw=home?fs(224):anchor.width(),total=2+2*pad+count*row+s(1)*std::max(0,count-1);
    qreal y=anchor.bottom()+s(1),mh=std::min(total,std::max(row+2*pad,viewport_.height()-y-s(2)));
    if(y+mh>viewport_.height()-s(2))y=std::max(s(2),qreal(viewport_.height())-s(2)-mh);
    const qreal menuX=std::max(s(2),std::min(anchor.x(),qreal(viewport_.width())-mw-s(2)));
    m.rect={menuX,y,std::min(mw,std::max(qreal(1),viewport_.width()-menuX-s(2))),mh};
    m.maxScroll=std::max(0,int(std::ceil(total-mh)));
    const int scroll=std::min(m.maxScroll,menuScroll_);
    const QStringList names=home?QStringList{QStringLiteral("人员检测"),QStringLiteral("车辆检测"),QStringLiteral("安全帽检测"),QStringLiteral("缺陷检测")}:
                                         QStringList{QStringLiteral("人员"),QStringLiteral("车辆"),QStringLiteral("安全帽"),QStringLiteral("缺陷")};
    for(int i=0;i<count;++i) {
        Hit a;a.rect={m.rect.x()+1+pad,m.rect.y()+1+pad+i*(row+s(1))-scroll,m.rect.width()-2-2*pad,row};
        if(video) {
            a.id=QString("local-video-%1").arg(i);a.label=localVideos.isEmpty()?QStringLiteral("请将视频放入视频目录"):localVideos[i];
            a.kind=Action::LocalVideo;a.value=i;a.enabled=!localVideos.isEmpty();m.hits.push_back(a);continue;
        }
        a.id=i<4?QStringLiteral("category-%1").arg(i):QStringLiteral("installed-model-%1").arg(i-4);
        a.label=i<4?names[i]:availableModels[i-4];a.kind=Action::Model;a.camera=menu_;a.value=i-4;
        a.enabled=i>=4;
        m.hits.push_back(a);
    }
    return m;
}

inline void Frontend::icon(QPainter& p,QRectF r,const QString& name,QColor color) {
    p.save();p.translate(r.topLeft());p.scale(r.width()/24,r.height()/24);
    p.setBrush(Qt::NoBrush);p.setPen(QPen(color,2,Qt::SolidLine,Qt::RoundCap,Qt::RoundJoin));
    QPainterPath path;
    auto line=[&](qreal a,qreal b,qreal c,qreal d){path.moveTo(a,b);path.lineTo(c,d);};
    if(name=="arrow-left"||name=="arrow-right"||name=="arrow-up") {
        if(name=="arrow-left"){line(19,12,5,12);path.moveTo(12,19);path.lineTo(5,12);path.lineTo(12,5);}
        else if(name=="arrow-right"){line(5,12,19,12);path.moveTo(12,5);path.lineTo(19,12);path.lineTo(12,19);}
        else {line(12,19,12,5);path.moveTo(5,12);path.lineTo(12,5);path.lineTo(19,12);}
    } else if(name=="corner-up-left"||name=="corner-up-right") {
        // SVG quarter-circle arcs (r=4), represented by the standard cubic.
        if(name=="corner-up-left"){path.moveTo(9,14);path.lineTo(4,9);path.lineTo(9,4);path.moveTo(20,20);path.lineTo(20,13);path.cubicTo(20,10.790861,18.209139,9,16,9);path.lineTo(4,9);}
        else {path.moveTo(15,14);path.lineTo(20,9);path.lineTo(15,4);path.moveTo(4,20);path.lineTo(4,13);path.cubicTo(4,10.790861,5.790861,9,8,9);path.lineTo(20,9);}
    } else if(name=="chevron-down") {path.moveTo(6,9);path.lineTo(12,15);path.lineTo(18,9);
    } else if(name=="monitor") {path.addRoundedRect(QRectF(2,3,20,14),2,2);line(8,21,16,21);line(12,17,12,21);
    } else if(name=="video") {
        path.moveTo(16,13);path.lineTo(21.223,16.482);path.cubicTo(21.555,16.703,22,16.465,22,16.066);path.lineTo(22,7.87);path.cubicTo(22,7.487,21.587,7.246,21.248,7.438);path.lineTo(16,10.5);
        path.addRoundedRect(QRectF(2,6,14,12),2,2);
    } else if(name=="layout-grid"||name=="grid-2x2") {
        if(name=="grid-2x2"){path.addRoundedRect(QRectF(3,3,18,18),2,2);line(12,3,12,21);line(3,12,21,12);}
        else for(int y:{3,14})for(int x:{3,14})path.addRoundedRect(QRectF(x,y,7,7),1,1);
    } else if(name=="layers") {
        path.moveTo(12.83,2.18);path.lineTo(20,6);path.cubicTo(20.39,6.2,20.64,6.44,20.77,6.81);
        path.cubicTo(20.9,7.17,20.85,7.58,20.6,7.9);path.cubicTo(20.49,8.04,20.35,8.16,20,8.33);
        path.lineTo(12.83,12.23);path.cubicTo(12.56,12.38,12.28,12.46,12,12.46);
        path.cubicTo(11.72,12.46,11.44,12.38,11.17,12.23);path.lineTo(4,8.33);
        path.cubicTo(3.65,8.16,3.51,8.04,3.4,7.9);path.cubicTo(3.15,7.58,3.1,7.17,3.23,6.81);
        path.cubicTo(3.36,6.44,3.61,6.2,4,6);path.lineTo(11.17,2.18);
        path.cubicTo(11.43,2.06,11.71,2,12,2);path.cubicTo(12.29,2,12.57,2.06,12.83,2.18);
        path.moveTo(22,12.5);path.lineTo(12.83,16.43);path.cubicTo(12.56,16.58,12.28,16.66,12,16.66);
        path.cubicTo(11.72,16.66,11.44,16.58,11.17,16.43);path.lineTo(2,12.5);
        path.moveTo(22,17.5);path.lineTo(12.83,21.43);path.cubicTo(12.56,21.58,12.28,21.66,12,21.66);
        path.cubicTo(11.72,21.66,11.44,21.58,11.17,21.43);path.lineTo(2,17.5);
    } else if(name=="maximize-2") {
        path.moveTo(15,3);path.lineTo(21,3);path.lineTo(21,9);path.moveTo(9,21);path.lineTo(3,21);path.lineTo(3,15);line(21,3,14,10);line(3,21,10,14);
    } else if(name=="sliders-horizontal") {
        line(10,5,3,5);line(12,19,3,19);line(14,3,14,7);line(16,17,16,21);
        line(21,12,12,12);line(21,19,16,19);line(21,5,14,5);line(8,10,8,14);line(8,12,3,12);
    } else if(name=="ruler") {
        path.moveTo(21.3,15.3);path.cubicTo(22.238,16.239,22.238,17.761,21.3,18.7);path.lineTo(18.7,21.3);
        path.cubicTo(17.761,22.238,16.239,22.238,15.3,21.3);path.lineTo(2.7,8.7);
        path.cubicTo(1.761,7.761,1.761,6.239,2.7,5.3);path.lineTo(5.3,2.7);
        path.cubicTo(6.239,1.761,7.761,1.761,8.7,2.7);path.closeSubpath();
        line(14.5,12.5,16.5,10.5);line(11.5,9.5,13.5,7.5);line(8.5,6.5,10.5,4.5);line(17.5,15.5,19.5,13.5);
    } else if(name=="check") {path.moveTo(4,12);path.lineTo(9,17);path.lineTo(20,6);}
    p.drawPath(path);p.restore();
}

inline QString Frontend::zoomInfo(int camera) const {
    const QString resolution=resName(hd[camera]?720:(camera==2||camera==3?240:480));
    return (page==Page::Four?QStringLiteral("分辨率 "):QString())+resolution+QStringLiteral(" · ")+rateLabel(camera)+(sensorName.isEmpty()?QString():QStringLiteral(" · ")+sensorName);
}

// Home 深色页辅助绘制。只读已有字段，不引入新的数据来源。
inline void Frontend::homeCard(QPainter& p,const QRectF& r,const QRectF& title,const QString& label) const {
    if(r.isEmpty())return;
    box(p,r,homePanel(),homeLine(),fs(10),1);
    p.save();p.setRenderHint(QPainter::Antialiasing);
    p.fillRect(QRectF(r.left()+s(2),title.center().y()-fs(8),fs(3),fs(16)),homeAccent());
    p.setPen(QPen(homeLine(),1));
    p.drawLine(QPointF(r.left()+s(2),title.bottom()+s(.5)),
               QPointF(r.right()-s(2),title.bottom()+s(.5)));
    p.restore();
    text(p,QRectF(r.left()+s(8),title.y(),std::max(qreal(1),r.width()-s(10)),title.height()),
         label,17,homeInk(),QFont::DemiBold);
}

inline void Frontend::homeChip(QPainter& p,const QRectF& r,const QString& label,bool active,bool enabled) const {
    if(r.isEmpty())return;
    p.save();p.setRenderHint(QPainter::Antialiasing);
    // 只用禁用态降透明度；未选中的切换按钮仍然是可读可点的正常外观。
    if(!enabled)p.setOpacity(.35);
    box(p,r,active?QColor("#13283c"):homePanel(),active?homeAccent():homeLine(),fs(6),1);
    text(p,r,label,11,active?homeAccent():homeDim(),QFont::DemiBold,Qt::AlignCenter);
    p.restore();
}

inline void Frontend::homeTab(QPainter& p,const QRectF& r,const QString& label,const QString& glyph,
                              bool active,bool enabled) const {
    if(r.isEmpty())return;
    p.save();p.setRenderHint(QPainter::Antialiasing);
    if(!enabled)p.setOpacity(.35);
    box(p,r,active?QColor(68,216,195,26):QColor(12,24,33),active?QColor(68,216,195,150):homeLine(),fs(6),1);
    const QColor tone=active?homeAccent():homeDim();
    const qreal iconSide=std::min(r.height()*.5,fs(15));
    const qreal tw=textWidth(label,12);
    qreal x=r.center().x()-(iconSide+s(2)+tw)/2;
    icon(p,QRectF(x,r.center().y()-iconSide/2,iconSide,iconSide),glyph,tone);
    text(p,QRectF(x+iconSide+s(2),r.y(),tw+s(2),r.height()),label,12,tone,QFont::DemiBold);
    p.restore();
}

inline void Frontend::homeGlyph(QPainter& p,const QRectF& r,const QString& name,const QColor& color) const {
    if(r.isEmpty())return;
    if(name=="arrow-left"||name=="arrow-right"||name=="arrow-up"||
       name=="corner-up-left"||name=="corner-up-right"){icon(p,r,name,color);return;}
    p.save();p.setRenderHint(QPainter::Antialiasing);
    p.translate(r.topLeft());p.scale(r.width()/24.,r.height()/24.);
    p.setBrush(Qt::NoBrush);
    p.setPen(QPen(color,2,Qt::SolidLine,Qt::RoundCap,Qt::RoundJoin));
    QPainterPath path;
    if(name=="car") {
        // 简化车身：底盘 + 车厢轮廓 + 两个车轮。
        path.moveTo(3,16);path.lineTo(3,12.5);path.cubicTo(3,11.4,3.9,10.5,5,10.5);path.lineTo(6.6,10.5);
        path.lineTo(8.4,7.0);path.cubicTo(8.8,6.3,9.5,5.9,10.3,5.9);path.lineTo(14.9,5.9);
        path.cubicTo(15.7,5.9,16.4,6.3,16.8,7.0);path.lineTo(18.4,10.5);path.lineTo(19,10.5);
        path.cubicTo(20.1,10.5,21,11.4,21,12.5);path.lineTo(21,16);
        path.moveTo(3.4,16);path.lineTo(20.6,16);
        path.moveTo(7.4,16);path.arcTo(QRectF(5.2,14.1,4.4,4.4),180,180);
        path.moveTo(16.6,16);path.arcTo(QRectF(14.4,14.1,4.4,4.4),180,180);
    } else if(name=="video") {
        path.addRoundedRect(QRectF(2,6,13,12),2,2);
        path.moveTo(16,12.5);path.lineTo(21.2,15.9);path.lineTo(21.2,8.1);path.closeSubpath();
    } else if(name=="play") {
        p.setPen(Qt::NoPen);p.setBrush(color);
        path.moveTo(9,7);path.lineTo(17.5,12);path.lineTo(9,17);path.closeSubpath();
    } else if(name=="stop") {
        p.setPen(QPen(color,2.2));p.setBrush(Qt::NoBrush);
        path.addRoundedRect(QRectF(8.5,8.5,7,7),1.4,1.4);
    } else if(name=="violation") {
        p.drawEllipse(QPointF(12,12),8,8);
        p.drawLine(QPointF(6.6,17.4),QPointF(17.4,6.6));
        p.restore();
        return;
    } else if(name=="alert") {
        p.drawEllipse(QPointF(12,12),8,8);
        p.drawLine(QPointF(12,7.6),QPointF(12,13));
        p.setBrush(color);p.drawEllipse(QPointF(12,16.2),1.1,1.1);
        p.restore();
        return;
    } else if(name=="absent") {
        p.setPen(QPen(color,1.4,Qt::DashLine));
        p.drawEllipse(QPointF(12,12),8,8);
        p.restore();
        return;
    } else if(name=="person") {
        p.setBrush(color);p.setPen(Qt::NoPen);
        p.drawEllipse(QPointF(12,6.2),3.1,3.1);
        p.setPen(QPen(color,2,Qt::SolidLine,Qt::RoundCap,Qt::RoundJoin));
        path.moveTo(12,9.6);path.lineTo(12,15.4);
        path.moveTo(7.6,12.2);path.lineTo(12,10.4);path.lineTo(16.4,12.2);
        path.moveTo(9.2,20.6);path.lineTo(12,15.4);path.lineTo(14.8,20.6);
    } else if(name=="bike") {
        p.drawEllipse(QPointF(6.4,17.6),3.9,3.9);
        p.drawEllipse(QPointF(17.6,17.6),3.9,3.9);
        path.moveTo(6.4,17.6);path.lineTo(10.2,10.4);path.lineTo(14.6,17.6);
        path.moveTo(10.2,10.4);path.lineTo(16.4,10.4);
        path.moveTo(14.6,17.6);path.lineTo(16.4,10.4);
    } else if(name=="bus") {
        path.addRoundedRect(QRectF(5.5,4.2,13,12.6),2.2,2.2);
        path.moveTo(5.5,10.6);path.lineTo(18.5,10.6);
        p.drawPath(path);
        p.setBrush(color);p.setPen(Qt::NoPen);
        p.drawEllipse(QPointF(8.6,18.4),1.9,1.9);
        p.drawEllipse(QPointF(15.4,18.4),1.9,1.9);
        path=QPainterPath();
    } else if(name=="motor") {
        p.drawEllipse(QPointF(6.2,17.4),3.7,3.7);
        p.drawEllipse(QPointF(17.8,17.4),3.7,3.7);
        path.moveTo(6.2,17.4);path.lineTo(9.8,11.2);path.lineTo(15.2,11.2);
        path.moveTo(15.2,11.2);path.lineTo(17.8,17.4);
        path.moveTo(9.8,11.2);path.lineTo(12.4,14.4);
    }
    p.drawPath(path);p.restore();
}

inline QString Frontend::videoMetaText() const {
    // 分辨率/帧率取真实采集值；推理帧率由 main 按推理线程指标填写。
    const QString resolution=QStringLiteral("%1 × %2").arg(hd[0]?1280:640).arg(hd[0]?720:480);
    const QString rate=fps[0]>0?QString::number(fps[0],'f',0)+QStringLiteral(" 帧/秒"):dash();
    const QString infer=inferenceRate.isEmpty()?dash():inferenceRate+QStringLiteral(" 帧/秒");
    return resolution+QStringLiteral("  |  ")+rate+QStringLiteral("  |  推理 ")+infer;
}

inline QString Frontend::vehicleActionStateText() const {
    if(!recognitionRunning)return QStringLiteral("识别已关闭");
    if(!drivingRequested)return QStringLiteral("停止请求");
    const QString state=vehicleAction.state;
    if(state==QStringLiteral("Stopped"))return QStringLiteral("停止请求");
    if(state==QStringLiteral("EmergencyLatched"))return QStringLiteral("紧急锁存");
    if(state==QStringLiteral("RuleBlocked"))return QStringLiteral("规则禁止");
    if(state==QStringLiteral("Allowed"))return QStringLiteral("规则许可");
    return QStringLiteral("等待证据");
}

inline vehicle_action::Color Frontend::predictColor(int ring,bool parked) const {
    // 设计稿第 1 页的中间「停止」卡对应本状态机的普通停车结果；直行卡此时不亮，
    // 避免同一证据在两张卡上重复显示。
    if(ring==2)return parked?vehicle_action::Color::Red:vehicle_action::Color::Gray;
    if(ring==1&&parked)return vehicle_action::Color::Gray;
    const int cards[6]={0,1,-1,2,3,4};
    const int card=cards[ring];
    return card<0?vehicle_action::Color::Gray:status_bar::activeColor(vehicleAction,card,showIntent);
}

inline int Frontend::homeLightCode() const {
    // 灯色编码沿用 driving_traffic_permission::LightColor：1 红 / 2 黄 / 3 绿。
    if(!recognitionRunning||!drivingState[QStringLiteral("lights_fresh")].toBool())return 0;
    int code=0;double best=-1;
    for(const auto& value:drivingState[QStringLiteral("light_detections")].toArray()) {
        const auto light=value.toObject();
        const int color=light[QStringLiteral("color")].toInt();
        if(color<1||color>3)continue;
        const double confidence=light[QStringLiteral("confidence")].toDouble();
        if(confidence>=best){best=confidence;code=color;}
    }
    return code;
}

inline QString Frontend::homeLightText() const {
    const int code=homeLightCode();
    return code==1?QStringLiteral("红灯"):code==2?QStringLiteral("黄灯"):
        code==3?QStringLiteral("绿灯"):QStringLiteral("未检测");
}

inline QColor Frontend::homeLightColor() const {
    const int code=homeLightCode();
    return code==1?QColor("#ef4444"):code==2?QColor("#f59e0b"):
        code==3?QColor("#22c55e"):QColor("#4a5d72");
}

inline QString Frontend::homeLightPermissionText() const {
    // 许可结论只来自既有驱动证据：区域已配置、灯组稳定且新鲜，否则一律“待确认”。
    const QString direction=assumedLane<0?QStringLiteral("左转"):assumedLane>0?QStringLiteral("右转"):QStringLiteral("直行");
    if(!recognitionRunning)return QStringLiteral("识别已关闭");
    const bool confirmed=drivingState[QStringLiteral("lights_fresh")].toBool()&&
        drivingState[QStringLiteral("ahead_roi_configured")].toBool()&&
        drivingState[QStringLiteral("lights_stable")].toBool();
    if(!confirmed)return direction+QStringLiteral("通行许可待确认");
    const char* key=assumedLane<0?"left":assumedLane>0?"right":"straight";
    const int permission=drivingState[QString::fromLatin1(key)].toInt();
    return direction+(permission==1?QStringLiteral("允许"):permission==2?QStringLiteral("禁止"):
        permission==3?QStringLiteral("不适用"):QStringLiteral("许可待确认"));
}

inline QRectF Frontend::legendOverlayRect() const {
    // 识别对照浮层（11 类目标 + 7 类标线）覆盖在主画面上，工具条按钮保持可点以再次关闭。
    const QRectF area=layout().homeFrame;
    if(area.isEmpty())return QRectF();
    const qreal wide=std::min(std::max(qreal(160),area.width()-s(4)),fs(760));
    const qreal high=std::min(std::max(fs(180),area.height()-s(4)),fs(420));
    return QRectF(area.center()-QPointF(wide/2,high/2),QSizeF(wide,high));
}

inline void Frontend::paintLanePreview(QPainter& p,const QRectF& rect,const QString& title) const {
    p.save();p.setRenderHint(QPainter::Antialiasing);
    box(p,rect,homePanel(),homeLine(),fs(10),1);
    p.save();p.setRenderHint(QPainter::Antialiasing);
    p.fillRect(QRectF(rect.left()+s(2),rect.top()+s(3),fs(3),fs(14)),homeAccent());
    p.restore();
    text(p,{rect.left()+s(8),rect.top()+s(1),rect.width()-s(10),fs(20)},title,13,homeInk(),QFont::DemiBold);
    const QRectF inner=rect.adjusted(fs(2),fs(24),-fs(2),-fs(2));
    p.save();p.setClipRect(inner,Qt::IntersectClip);
    // 透视地面 + 网格，作为"感知视图"底图；有真实车道掩码时再叠在上面。
    p.fillRect(inner,QColor("#081019"));
    const qreal vx=inner.center().x(),vy=inner.top()+inner.height()*.24;
    const qreal bottomY=inner.bottom()-fs(4);
    const qreal lb=inner.left()+inner.width()*.14,rb=inner.right()-inner.width()*.14;
    p.setPen(QPen(QColor(68,216,195,34),1));
    for(int i=1;i<=5;++i) {
        const qreal y=vy+(bottomY-vy)*std::pow(i/5.0,1.7);
        p.drawLine(QPointF(inner.left(),y),QPointF(inner.right(),y));
    }
    for(int i=-4;i<=4;++i) {
        p.drawLine(QPointF(vx+i*(inner.width()*.075),bottomY),
                   QPointF(vx+i*(inner.width()*.016),vy));
    }
    // 左右车道边界线（亮青），与设计稿一致。
    p.setPen(QPen(QColor("#44d8c3"),std::max(qreal(1),fs(1.4))));
    p.drawLine(QPointF(lb,bottomY),QPointF(vx-inner.width()*.105,vy));
    p.drawLine(QPointF(rb,bottomY),QPointF(vx+inner.width()*.105,vy));
    // 中间车道虚线
    p.setPen(QPen(QColor(226,240,242,120),std::max(qreal(1),fs(1)),Qt::DashLine));
    p.drawLine(QPointF(vx,bottomY),QPointF(vx,vy));
    // 前方两个目标车（示意），尺寸随远近缩放。
    for(int i=0;i<2;++i) {
        const qreal t=i?0.26:0.46;
        const qreal cx=vx+(i?inner.width()*.075:-inner.width()*.05);
        const qreal cy=vy+(bottomY-vy)*t;
        const qreal cw=inner.width()*(i?.042:.055);
        const qreal ch=cw*1.35;
        p.setPen(QPen(QColor(68,216,195,140),std::max(qreal(1),fs(1))));
        p.setBrush(QColor(14,36,48,230));
        p.drawRoundedRect(QRectF(cx-cw/2,cy-ch/2,cw,ch),fs(2),fs(2));
    }
    if(!lanePreview.isNull()) {
        const QRect source=lanePreview.rect();
        const qreal scale=std::min(inner.width()/source.width(),inner.height()/source.height());
        const QSizeF fitted(source.width()*scale,source.height()*scale);
        p.setOpacity(.55);
        p.drawImage(QRectF(inner.center()-QPointF(fitted.width()/2,fitted.height()/2),fitted),
                    lanePreview,source);
        p.setOpacity(1);
    }
    // 自车：车身 + 风挡，始终画在最上层。
    const QRectF ego(inner.center().x()-inner.width()*.055,inner.bottom()-inner.height()*.19,
                     inner.width()*.11,inner.height()*.15);
    p.setPen(Qt::NoPen);
    p.setBrush(QColor(0,0,0,90));
    p.drawEllipse(QRectF(ego.left()+ego.width()*.05,ego.bottom()-ego.height()*.06,
                         ego.width()*.9,ego.height()*.16));
    p.setBrush(QColor("#e6eef7"));
    p.drawRoundedRect(ego,fs(4),fs(4));
    const QRectF roof(ego.left()+ego.width()*.16,ego.top()+ego.height()*.12,
                      ego.width()*.68,ego.height()*.40);
    p.setBrush(QColor("#8fa6bd"));
    p.drawRoundedRect(roof,fs(2),fs(2));
    p.setBrush(QColor("#dbe5f0"));
    p.drawRoundedRect(QRectF(ego.left()+ego.width()*.1,ego.bottom()-ego.height()*.22,
                             ego.width()*.8,ego.height()*.14),fs(2),fs(2));
    if(lanePreview.isNull())
        text(p,QRectF(inner.left()+s(3),inner.top()+s(2),inner.width()-s(6),fs(14)),
             QStringLiteral("暂无标线数据 · 示意"),9,QColor("#587a8c"),QFont::Normal);
    p.restore();p.restore();
}

inline void Frontend::paint(QPainter& p) const {
    const Layout l=layout();p.save();p.setRenderHint(QPainter::Antialiasing);p.setClipRect(viewRect(),Qt::IntersectClip);
    // Only background/chrome is opaque. Never erase the textures already drawn by main.
    // Home 无帧时不挖洞：整张主画面卡用深色底和占位文案覆盖，避免露出光板底色。
    QRegion opaque(viewRect().toAlignedRect());
    const bool homeNoHole=page==Page::Home&&!hasFrame;
    for(const VideoTile& t:videoTiles())if(!homeNoHole)opaque-=QRegion(t.rect.toAlignedRect());
    const QRectF hr=hdmiVideoRect();if(!hr.isEmpty())opaque-=QRegion(hr.toAlignedRect());
    p.save();p.setClipRegion(opaque,Qt::IntersectClip);
    p.fillRect(viewRect(),page==Page::Home?homeBg():QColor(Qt::white));p.restore();
    if(zoomCamera>=0&&(page==Page::Six||page==Page::Four)) {
        button(p,l.back,QStringLiteral("返回"),"arrow-left");
        heading(p,l.title,channelLabel(zoomCamera)+QStringLiteral(" ")+cameraName(zoomCamera),16);
        box(p,l.zoom,Qt::transparent,border(),12);
        if(!hasFrame)icon(p,{l.zoom.center().x()-s(8),l.zoom.center().y()-s(8),s(16),s(16)},"video");
        const QString info=zoomInfo(zoomCamera);
        const qreal iw=std::min(std::max(qreal(1),l.zoom.width()-s(4)),textWidth(info,12)+s(4));
        QRectF ir(l.zoom.right()-s(2)-iw,l.zoom.bottom()-s(2)-fs(24),iw,fs(24));
        box(p,ir,QColor(255,255,255,230),Qt::transparent,4);text(p,ir.adjusted(s(2),0,-s(2),0),info,12,muted());
        p.restore();return;
    }
    p.translate(0,-offset());
    if(page==Page::Home) {
        // ── 顶栏：系统名 + 输入源 ───────────────────────────────────────────
        p.fillRect(l.homeBar,QColor("#0b1622"));
        p.setPen(QPen(QColor("#16283a"),1));
        p.drawLine(QPointF(l.homeBar.left(),l.homeBar.bottom()),QPointF(l.homeBar.right(),l.homeBar.bottom()));
        homeGlyph(p,QRectF(l.homeBarTitle.left(),l.homeBarTitle.center().y()-fs(9),fs(18),fs(18)),
                  QStringLiteral("car"),homeAccent());
        text(p,l.homeBarTitle.adjusted(fs(24),0,0,0),QStringLiteral("ADAS 智能驾驶感知系统"),27,homeInk(),QFont::DemiBold);
        // 当前输入源高亮：本地视频/HDMI 走 HDMI 输入，其余为相机输入。
        homeTab(p,l.homeSourceCamera,QStringLiteral("OV5640 输入"),QStringLiteral("video"),!localVideoActive);
        homeTab(p,l.homeSourceHdmi,QStringLiteral("HDMI 输入"),QStringLiteral("monitor"),localVideoActive);
        // ── 次行：页面名 + 视图切换 ─────────────────────────────────────────
        text(p,l.homeSubTitle,QStringLiteral("城市道路感知"),18,homeInk(),QFont::DemiBold);
        homeTab(p,l.homeViewSingle,QStringLiteral("单路视图"),QStringLiteral("monitor"),true);
        homeTab(p,l.homeViewFour,QStringLiteral("四路视图"),QStringLiteral("layout-grid"),false);
        homeTab(p,l.homeViewSix,QStringLiteral("六路视图"),QStringLiteral("grid-2x2"),false);
        homeTab(p,l.homeViewSpace,QStringLiteral("空间视图"),QStringLiteral("layers"),false,panoramaSupported);
        // ── 主画面卡：标题 + 分辨率/帧率 + 画面（画面区域留给 main 贴纹理）───────
        p.save();
        QRegion videoCard(l.homeVideo.toAlignedRect());
        // 有帧时挖掉画面区域，否则会盖住 main 已画好的视频；无帧时整卡填底色再写占位文案。
        if(hasFrame&&l.homeFrame.isValid())videoCard-=QRegion(l.homeFrame.toAlignedRect());
        p.setClipRegion(videoCard,Qt::IntersectClip);
        box(p,l.homeVideo,homePanel(),homeLine(),fs(10),1);
        p.restore();
        homeGlyph(p,QRectF(l.homeVideoTitle.left(),l.homeVideoTitle.center().y()-fs(6),fs(12),fs(12)),
                  QStringLiteral("video"),homeAccent());
        text(p,l.homeVideoTitle.adjusted(fs(15),0,0,0),QStringLiteral("前视主摄像头 01"),12,homeInk(),QFont::DemiBold);
        text(p,l.homeVideoMeta,videoMetaText(),10,homeDim(),QFont::Normal,Qt::AlignRight|Qt::AlignVCenter);
        if(!hasFrame) {
            icon(p,QRectF(l.homeFrame.center().x()-s(8),l.homeFrame.center().y()-s(8),s(16),s(16)),
                 QStringLiteral("video"),homeDim());
            text(p,QRectF(l.homeFrame.left(),l.homeFrame.center().y()+s(10),l.homeFrame.width(),fs(20)),
                 QStringLiteral("等待相机画面"),11,homeDim(),QFont::Normal,Qt::AlignCenter);
        } else {
            // 画面外描一圈细边，与设计稿的"画中画"观感一致。
            p.save();p.setRenderHint(QPainter::Antialiasing);
            p.setPen(QPen(homeLine(),1));p.setBrush(Qt::NoBrush);
            p.drawRoundedRect(l.homeFrame.adjusted(-1,-1,1,1),fs(4),fs(4));
            p.restore();
        }
        // ── 信号灯浮层：灯色 + 前视距离 + 当前方向通行许可 ─────────────────────
        if(hasFrame&&l.homeLight.isValid()) {
            const QColor lightColor=homeLightColor();
            p.save();p.setClipRect(l.homeLight,Qt::IntersectClip);
            p.setRenderHint(QPainter::Antialiasing);
            QPainterPath lightPath;lightPath.addRoundedRect(l.homeLight,fs(6),fs(6));
            p.fillPath(lightPath,QColor(6,17,28,208));
            p.setPen(QPen(QColor(56,189,248,110),1));p.setBrush(Qt::NoBrush);p.drawPath(lightPath);
            text(p,QRectF(l.homeLight.left()+s(2),l.homeLight.top()+s(1),
                          std::max(qreal(1),l.homeLight.width()-s(4)),fs(18)),
                 QStringLiteral("信号灯识别"),10,homeDim(),QFont::Normal);
            const QString badge=homeLightText();
            const qreal badgeW=textWidth(badge,10)+s(4);
            const QRectF badgeRect(l.homeLight.right()-s(2)-badgeW,l.homeLight.top()+s(1),badgeW,fs(17));
            p.save();p.setRenderHint(QPainter::Antialiasing);
            p.setPen(QPen(lightColor,1));p.setBrush(QColor(lightColor.red(),lightColor.green(),lightColor.blue(),44));
            p.drawRoundedRect(badgeRect,fs(8),fs(8));p.restore();
            text(p,badgeRect,badge,10,lightColor,QFont::DemiBold,Qt::AlignCenter);
            text(p,QRectF(l.homeLight.left()+s(3),l.homeLight.top()+fs(22),
                          std::max(qreal(1),l.homeLight.width()-s(6)),fs(26)),
                 QStringLiteral("↑ ")+(showDistance?(frontDistance.isEmpty()?dash():frontDistance):QStringLiteral("已隐藏")),
                 16,homeInk(),QFont::DemiBold);
            text(p,QRectF(l.homeLight.left()+s(3),l.homeLight.top()+fs(52),
                          std::max(qreal(1),l.homeLight.width()-s(6)),fs(18)),
                 homeLightPermissionText(),10,homeDim(),QFont::Normal);
            p.restore();
        }
        // ── 统计条：五类目标计数 + 融合目标 ─────────────────────────────────
        box(p,l.homeStats,homePanel(),homeLine(),fs(8),1);
        {
            const QString statLabels[5]={QStringLiteral("机动车"),QStringLiteral("行人"),QStringLiteral("自行车"),
                QStringLiteral("公交车"),QStringLiteral("摩托车")};
            const QString statKeys[5]={"car","person","bike","bus","motor"};
            const qreal statW=l.homeStats.width()-fs(120);
            const qreal statCell=statW/5;
            for(int i=0;i<5;++i) {
                const qreal sx=l.homeStats.left()+statCell*i;
                const QColor tone=detection_style::color(statKeys[i]);
                // 设计稿：类别图标在左，名称与两位计数紧随其后。
                const qreal glyphSide=std::min(fs(15),l.homeStats.height()*.55);
                homeGlyph(p,QRectF(sx+s(2),l.homeStats.center().y()-glyphSide/2,glyphSide,glyphSide),
                          statKeys[i],tone);
                const qreal textX=sx+s(2)+glyphSide+s(2);
                // 窄屏（竖屏）只留图标 + 两位数，避免名称与数字互相压字。
                const bool compactStat=statCell<fs(112);
                if(!compactStat)
                    text(p,QRectF(textX,l.homeStats.y(),statCell*.5,l.homeStats.height()),
                         statLabels[i],12,homeDim(),QFont::Normal);
                text(p,QRectF(compactStat?textX:textX+textWidth(statLabels[i],12)+s(1),l.homeStats.y(),
                              statCell*.4,l.homeStats.height()),
                     QStringLiteral("%1").arg(homeClassCounts[size_t(i)],2,10,QChar('0')),
                     18,homeInk(),QFont::DemiBold);
            }
            text(p,QRectF(l.homeStats.right()-fs(118),l.homeStats.y(),fs(112),l.homeStats.height()),
                 QStringLiteral("融合目标 %1 个").arg(homeFusedCount),10,homeDim(),QFont::Normal,
                 Qt::AlignRight|Qt::AlignVCenter);
        }
        // ── 车辆下一步行动预测：车图标 + 六个圆卡 ───────────────────────────
        box(p,l.homePredict,homePanel(),homeLine(),fs(10),1);
        p.save();p.setRenderHint(QPainter::Antialiasing);
        p.fillRect(QRectF(l.homePredictTitle.left()-s(1),l.homePredictTitle.center().y()-fs(7),fs(3),fs(14)),
                   homeAccent());
        p.restore();
        text(p,l.homePredictTitle,QStringLiteral("车辆下一步行动预测"),11,homeInk(),QFont::DemiBold);
        text(p,l.homePredictState,vehicleActionStateText(),10,homeDim(),QFont::Normal,
             Qt::AlignRight|Qt::AlignVCenter);
        // 车身图标按等比正方形绘制，避免被卡片高度拉长。
        {
            const QRectF area=l.homePredictCar;
            const qreal side=std::max(fs(16),std::min(area.width(),area.height()));
            const QRectF circle(area.center().x()-side/2,area.center().y()-side/2,side,side);
            p.save();p.setRenderHint(QPainter::Antialiasing);
            p.setPen(QPen(QColor(68,216,195,150),std::max(qreal(1),fs(1.2))));
            p.setBrush(Qt::NoBrush);p.drawEllipse(circle.adjusted(1,1,-1,-1));p.restore();
            homeGlyph(p,circle.adjusted(circle.width()*.26,circle.height()*.26,
                                        -circle.width()*.26,-circle.height()*.26),
                      QStringLiteral("car"),homeAccent());
        }
        text(p,l.homePredictCaption,QStringLiteral("下一步将要"),14,homeInk(),QFont::DemiBold,
             Qt::AlignLeft|Qt::AlignVCenter);
        {
            const QString predictLabels[6]={QStringLiteral("左转向"),QStringLiteral("直行"),QStringLiteral("停止"),
                QStringLiteral("右转向"),QStringLiteral("违反交规"),QStringLiteral("急刹/避碰")};
            const QString predictGlyphs[6]={"arrow-left","arrow-up","stop","arrow-right","violation","alert"};
            // 设计稿：每个动作有固定身份色；激活时改用状态色（绿/红）并按既有规则闪动。
            const QColor identity[6]={QColor("#2fe6ff"),QColor("#9dfe41"),QColor("#ff3b30"),
                                      QColor("#2fe6ff"),QColor("#ffbc34"),QColor("#ff4d8d")};
            const bool parked=status_bar::parking(vehicleAction);
            for(int i=0;i<6;++i) {
                const vehicle_action::Color state=predictColor(i,parked);
                const bool active=state!=vehicle_action::Color::Gray;
                const bool lit=active&&statusBlinkPhase;
                const QColor stateTone=state==vehicle_action::Color::Red?QColor("#ef4444"):
                    state==vehicle_action::Color::Yellow?QColor("#f59e0b"):QColor("#22c55e");
                const QColor base=identity[i];
                // 激活时按既有规则灰/状态色交替闪动；未激活保持身份色。
                const QColor tone=!active?base:(lit?stateTone:QColor("#4a5d72"));
                const QRectF ring=l.homePredictRings[size_t(i)];
                p.save();p.setRenderHint(QPainter::Antialiasing);
                p.setPen(QPen(tone,std::max(qreal(2),fs(2.4))));
                p.setBrush(active?QColor(tone.red(),tone.green(),tone.blue(),lit?40:12):QColor(tone.red(),tone.green(),tone.blue(),14));
                p.drawEllipse(ring);p.restore();
                homeGlyph(p,ring.adjusted(ring.width()*.28,ring.height()*.28,
                                          -ring.width()*.28,-ring.height()*.28),predictGlyphs[i],tone);
                // 窄屏放不下一整行标签时只保留图标，避免文字互相覆盖。
                if(l.homePredictTags[size_t(i)].width()>fs(44))
                    text(p,l.homePredictTags[size_t(i)],predictLabels[i],15,tone,
                         lit?QFont::DemiBold:QFont::Normal,Qt::AlignCenter);
            }
        }
        // ── 右列：行驶控制 ────────────────────────────────────────────────
        homeCard(p,l.homeDrive,l.homeDriveTitle,QStringLiteral("行驶控制"));
        {
            const QString driveLabels[2]={QStringLiteral("行驶"),QStringLiteral("停止")};
            const QString driveHints[2]={QStringLiteral("接通动力"),QStringLiteral("切断动力")};
            for(int i=0;i<2;++i) {
                const QRectF ring=l.homeRings[size_t(i)];
                const bool feedback=driveFeedbackControl==i;
                const QColor tone=feedback?(i?QColor("#ef4444"):QColor("#22c55e")):homeDim();
                p.save();p.setRenderHint(QPainter::Antialiasing);
                p.setPen(QPen(tone,std::max(qreal(2),fs(2.4))));
                p.setBrush(QColor(tone.red(),tone.green(),tone.blue(),feedback?20:0));
                p.drawEllipse(ring);p.restore();
                homeGlyph(p,ring.adjusted(ring.width()*.3,ring.height()*.3,
                                          -ring.width()*.3,-ring.height()*.3),
                          i?QStringLiteral("stop"):QStringLiteral("play"),tone);
                const QRectF tag=l.homeDriveTags[size_t(i)];
                text(p,QRectF(tag.x(),tag.y(),tag.width(),tag.height()*.55),driveLabels[i],15,tone,
                     QFont::DemiBold,Qt::AlignCenter);
                text(p,QRectF(tag.x(),tag.y()+tag.height()*.52,tag.width(),tag.height()*.48),
                     driveHints[i],11,homeDim(),QFont::Normal,Qt::AlignCenter);
            }
        }
        // ── 右列：假定车道选择 ────────────────────────────────────────────
        homeCard(p,l.homeLane,l.homeLaneTitle,QStringLiteral("假定车道选择"));
        {
            const QString laneLabels[3]={QStringLiteral("左转车道"),QStringLiteral("直行车道"),QStringLiteral("右转车道")};
            const QString laneGlyphs[3]={"arrow-left","arrow-up","arrow-right"};
            for(int i=0;i<3;++i) {
                const bool selected=driveFeedbackControl==i+2;
                const QRectF ring=l.homeRings[size_t(i+2)];
                const QColor tone=QColor("#72c6ff");
                p.save();p.setRenderHint(QPainter::Antialiasing);
                p.setPen(QPen(tone,std::max(qreal(2),fs(2.4))));
                p.setBrush(selected?QColor(114,198,255,40):QColor(0,0,0,0));
                p.drawEllipse(ring);p.restore();
                homeGlyph(p,ring.adjusted(ring.width()*.3,ring.height()*.3,
                                          -ring.width()*.3,-ring.height()*.3),laneGlyphs[i],tone);
                const QRectF tag=l.homeLaneTags[size_t(i)];
                text(p,QRectF(tag.x(),tag.y(),tag.width(),tag.height()*.6),laneLabels[i],14,
                     QColor("#72c6ff"),QFont::DemiBold,Qt::AlignCenter);
                if(selected)
                    text(p,QRectF(tag.x(),tag.y()+tag.height()*.55,tag.width(),tag.height()*.45),
                          QStringLiteral("已选择"),10,QColor("#72c6ff"),QFont::DemiBold,Qt::AlignCenter);
            }
        }
        // ── 右列：变道控制 ────────────────────────────────────────────────
        homeCard(p,l.homeChange,l.homeChangeTitle,QStringLiteral("变道控制"));
        {
            const QString changeLabels[2]={QStringLiteral("向左变道"),QStringLiteral("向右变道")};
            const QString changeGlyphs[2]={"corner-up-left","corner-up-right"};
            for(int i=0;i<2;++i) {
                const QRectF r=l.homeChangeTags[size_t(i)];
                const bool requested=i?changeRequest>0:changeRequest<0;
                const QColor tone=requested&&statusBlinkPhase?QColor("#22c55e"):QColor("#3f9eff");
                p.save();p.setRenderHint(QPainter::Antialiasing);
                p.setPen(QPen(tone,1));
                p.setBrush(requested?QColor(34,197,94,34):QColor(8,20,32));
                p.drawRoundedRect(r,fs(6),fs(6));p.restore();
                // 设计稿：图标在上、文字在下，两者都水平居中。
                const qreal iconSide=std::min(fs(18),r.height()*.42);
                homeGlyph(p,QRectF(r.center().x()-iconSide/2,r.top()+r.height()*.12,iconSide,iconSide),
                          changeGlyphs[i],tone);
                text(p,QRectF(r.left(),r.top()+r.height()*.55,r.width(),r.height()*.4),
                     changeLabels[i],14,homeInk(),QFont::DemiBold,Qt::AlignCenter);
            }
        }
        // ── 右列：感知视图（既有车道俯视缩略图）─────────────────────────────
        paintLanePreview(p,l.homePreview,QStringLiteral("感知视图"));
        // ── 顶栏「识别设置」入口；四个工具控件收在弹层里 ─────────────────
        homeChip(p,l.homeGear,QString(),homeToolsPanel);
        icon(p,QRectF(l.homeGear.center().x()-s(7),l.homeGear.center().y()-s(7),s(14),s(14)),
             QStringLiteral("sliders-horizontal"),homeToolsPanel?homeAccent():homeDim());
        if(homeToolsPanel && !l.homeModel.isEmpty()) {
            box(p,l.homeTools,QColor("#0f1a26"),QColor("#1c3550"),fs(8),1);
            box(p,l.homeModel,QColor("#122437"),QColor("#25405c"),fs(6),1);
            const qreal labelW=textWidth(QStringLiteral("检测模型"),10)+s(1);
            text(p,QRectF(l.homeModel.left()+s(2),l.homeModel.y(),
                          std::max(qreal(1),labelW),l.homeModel.height()),
                 QStringLiteral("检测模型"),10,homeDim(),QFont::Normal);
            text(p,QRectF(l.homeModel.left()+s(2)+labelW,l.homeModel.y(),
                          std::max(qreal(1),l.homeModel.width()-s(9)-labelW),l.homeModel.height()),
                 homeModelSummary(),11,selectedModels.isEmpty()?homeDim():homeInk(),QFont::Normal);
            icon(p,QRectF(l.homeModel.right()-s(4),l.homeModel.center().y()-s(1.5),s(3),s(3)),
                 QStringLiteral("chevron-down"),homeDim());
            text(p,l.confidenceLabel,QStringLiteral("置信度"),11,homeDim(),QFont::Normal);
            homeChip(p,l.minus,QString(QChar(0x2212)),false,confidence>.1001);
            text(p,l.confidenceValue,QString::number(confidence,'f',2),11,homeInk(),QFont::DemiBold,
                 Qt::AlignCenter);
            homeChip(p,l.plus,QStringLiteral("+"),false,confidence<.8999);
            homeChip(p,l.homeLegendButton,
                     homeLegend?QStringLiteral("识别对照 ✓"):QStringLiteral("识别对照"),homeLegend);
            homeChip(p,l.homeDisplay,
                     displayPanel?QStringLiteral("识别/显示 ✓"):QStringLiteral("识别/显示"),displayPanel);
        }
        if(!status.isEmpty())
            text(p,l.footer,status,10,homeDim(),QFont::Normal,Qt::AlignCenter);
    } else {
        button(p,l.back,QStringLiteral("返回"),"arrow-left");
        heading(p,l.title,page==Page::Six?QStringLiteral("六路"):page==Page::Four?QStringLiteral("四路"):QStringLiteral("HDMI 输入"),page==Page::Hdmi?24:18);
        if(page==Page::Hdmi) {
            status_bar::source(p,l.videoSelect,l.videoStatus,
                QStringLiteral("物理 HDMI"),QStringLiteral("真实输入"));
            button(p,l.panoramaButton,hdmiPanoramaActive?QStringLiteral("退出全景"):QStringLiteral("全景融合"));
            box(p,l.hdmi,Qt::transparent,border(),12);
             const QRectF videoWindow=hdmiVideoRect().translated(0,offset());
             box(p,videoWindow.adjusted(-1,-1,1,1),Qt::transparent,border(),2);
            if(!hasFrame)icon(p,{videoWindow.center().x()-s(8),videoWindow.center().y()-s(8),s(16),s(16)},"monitor");
             if(!frameStatus.isEmpty())text(p,{videoWindow.x()+20,videoWindow.center().y()+40,videoWindow.width()-40,24},frameStatus,14,muted(),QFont::Normal,Qt::AlignCenter);
             if(driveWarningUntil>QDateTime::currentMSecsSinceEpoch()) {
                 const double ww=std::min(videoWindow.width()*.8,fs(580));
                 const QRectF warning(videoWindow.center().x()-ww/2,videoWindow.center().y()-fs(60),ww,fs(120));
                 box(p,warning,QColor(185,20,30,242),QColor("#ffb1b7"),14,3);
                 text(p,warning.adjusted(8,8,-8,-fs(46)),"禁止行驶",30,Qt::white,600,Qt::AlignCenter);
                 text(p,warning.adjusted(8,fs(67),-8,-8),"检测到红灯，请保持停止",16,Qt::white,600,Qt::AlignCenter);
             }
            if(localVideoActive && !aheadLightRegion.isEmpty()) {
                const auto image=localVideoImageRect().translated(0,offset());
                const QRectF selection(image.left()+aheadLightRegion.left()*image.width()/640,
                    image.top()+(aheadLightRegion.top()-80)*image.height()/480,
                    aheadLightRegion.width()*image.width()/640,aheadLightRegion.height()*image.height()/480);
                p.save();p.setClipRect(image);p.setPen(QPen(QColor("#ffb52e"),2,Qt::DashLine));p.setBrush(Qt::NoBrush);p.drawRect(selection);p.restore();
            }
             status_bar::paint(p,l.statusBar,changeRequest?changeRequest:assumedLane,
                               drivingRequested,showIntent,aebWarning,navReadout,&vehicleAction,statusBlinkPhase);
             QColor frame=blue();frame.setAlpha(128);
              box(p,l.rightTop,QColor("#f3f8ff"),frame,12,2);
            if(l.driving.height()>fs(28)) {
                 driving_controls_panel::paint(p,driving_controls_panel::artworkArea(l.driving),
                     assumedLane,changeRequest,drivingRequested,pressedDrive,aebWarning,statusBlinkPhase);
                   for(const auto& hit:l.hits)if(hit.kind==Action::LightRegion||hit.kind==Action::LightCount)button(p,hit.rect,hit.label,QString(),false,hit.enabled);
            }
            paintLanePreview(p,l.rightBottom);
             recognition_legend_panel::paint(p,recognition_legend_panel::layout(l.rightTop,legend));
            text(p,l.footer,!showIntent?QStringLiteral("ADS 2.0.1 · 意图显示已关闭"):drivingHint.isEmpty()?QStringLiteral("ADS 2.0.1 · HDMI 输入"):QStringLiteral("ADS 2.0.1 · ")+drivingHint,12,muted(),QFont::Normal,Qt::AlignCenter);
        } else {
            const bool four=page==Page::Four,pano=four&&panorama;
            box(p,l.badge,blue(),Qt::transparent,99);text(p,l.badge,four?QStringLiteral("4 路已配置"):QStringLiteral("6 路已配置"),12,Qt::white,QFont::Normal,Qt::AlignCenter);
            if(four)button(p,l.panoramaButton,QStringLiteral("全景融合"),"layers",panorama,panoramaSupported);
            for(const Tile& t:l.tiles) {
                // Rounded card is drawn with a hole even if it is partially off-screen.
                p.save();QRegion cardRegion(t.card.toAlignedRect());cardRegion-=QRegion(t.video.toAlignedRect());p.setClipRegion(cardRegion,Qt::IntersectClip);box(p,t.card,Qt::white,border(),12);p.restore();
                const qreal tx=t.title.x()+s(2),ty=t.title.y()+s(1.5);
                QRectF ch(tx,ty,textWidth(channelLabel(t.camera),12)+s(3),fs(20));
                box(p,ch,QColor("#eff1f4"),Qt::transparent,4);text(p,ch,channelLabel(t.camera),12,muted(),QFont::Normal,Qt::AlignCenter);
                text(p,{ch.right()+s(2),t.title.y(),t.title.width()-ch.width()-s(6),t.title.height()},cameraName(t.camera),14);
                if(four&&!sensorName.isEmpty())text(p,{t.title.right()-fs(100)-s(2),t.title.y(),fs(100),t.title.height()},sensorName,12,muted(),QFont::Normal,Qt::AlignRight|Qt::AlignVCenter);
                {
                    QRectF fpsRect(t.video.right()-s(1)-fs(38.21875),t.video.y()+s(1),fs(38.21875),fs(19));
                    box(p,fpsRect,QColor(255,255,255,230),Qt::transparent,4);text(p,fpsRect,rateLabel(t.camera),10,ink(),QFont::Normal,Qt::AlignCenter);
                }
                if(!hasFrame)icon(p,{t.video.center().x()-s(4),t.video.center().y()-s(4),s(8),s(8)},"video");
                icon(p,{t.video.right()-s(1)-s(4),t.video.bottom()-s(1)-s(4),s(4),s(4)},"maximize-2",muted());
                if(t.camera==1||t.camera==5) {
                    const qreal pillH=std::min(fs(24),std::max(qreal(1),t.resFrame.height()-2));
                    const qreal rw=textWidth("480p",12)+s(4);
                    QRectF rr(t.resFrame.x()+1,t.resFrame.center().y()-pillH/2,std::min(rw,t.resFrame.width()-2),pillH);
                    box(p,rr,QColor("#eff1f4"),Qt::transparent,4);text(p,rr,"480p",12,muted(),QFont::Normal,Qt::AlignCenter);
                    text(p,{rr.right()+s(1.5),t.resFrame.y(),std::max(qreal(0),t.resFrame.right()-rr.right()-s(1.5)),t.resFrame.height()},QStringLiteral("固定分辨率"),12,muted());
                } else {
                    box(p,t.resFrame);const QVector<int> vals=(t.camera==2||t.camera==3)?QVector<int>{240,480,720}:QVector<int>{480,720};
                    for(int i=0;i<vals.size();++i) {
                        const bool enabled=resolutionSupported[t.camera]&&!(ranging&&rangingLocked(t.camera));const bool selected=resolution[t.camera]==vals[i];
                        p.save();if(!enabled)p.setOpacity(.5);box(p,t.options[i],selected?blue():QColor(Qt::white),Qt::transparent,4);text(p,t.options[i],resName(vals[i]),12,selected?QColor(Qt::white):muted(),QFont::Medium,Qt::AlignCenter);p.restore();
                    }
                }
                text(p,t.modelLabel,QStringLiteral("模型"),10,muted());box(p,t.model);
                const QString selected=channelModelSummary(t.camera);text(p,t.model.adjusted(s(2),0,-s(7.5),0),selected,11,selected==QStringLiteral("未选择")?muted():ink());
                icon(p,{t.model.right()-s(2)-s(3.5),t.model.center().y()-s(1.75),s(3.5),s(3.5)},"chevron-down",muted());
            }
            if(pano) {
                text(p,{l.panoramaTitle.x(),l.panoramaTitle.y(),textWidth(QStringLiteral("全景融合"),14),l.panoramaTitle.height()},QStringLiteral("全景融合"));
                text(p,l.panoramaTitle.adjusted(textWidth(QStringLiteral("全景融合"),14)+s(2),0,0,0),QStringLiteral("四通道融合为一个视频画面"),12,muted());
                box(p,l.panorama,secondary(),border(),12);icon(p,{l.panorama.center().x()-s(5),l.panorama.center().y()-s(5),s(10),s(10)},"layers");
                // No fake composite. Main may paint a real panorama after this placeholder
                // or disable panoramaSupported (the default) when no fusion backend exists.
                const QString source=sensorName.isEmpty()?QString():sensorName+QStringLiteral(" x4");
                if(!source.isEmpty()){QRectF r(l.panorama.right()-s(2)-fs(100),l.panorama.bottom()-s(2)-fs(24),fs(100),fs(24));box(p,r,QColor(255,255,255,230),Qt::transparent,4);text(p,r,source,12,ink(),QFont::Medium,Qt::AlignCenter);}
            }
            box(p,l.toolbar,Qt::white,border(),12);
            if(!pano) {
                button(p,l.rangeButton,ranging?QStringLiteral("关闭测距"):QStringLiteral("开启测距"),"ruler",four?false:ranging,rangingSupported,false,four?ink():blue());
                for(int i=0;i<2;++i) {
                    const QRectF r=i?l.rear:l.front;box(p,r);
                    const qreal glyph=std::min(s(4),r.height()*.55);
                    icon(p,{r.x()+s(2),r.center().y()-glyph/2,glyph,glyph},"ruler");
                    const QString label=i?QStringLiteral("后方"):QStringLiteral("前方");
                    text(p,{r.x()+s(2)+glyph+s(1),r.y(),textWidth(label,11),r.height()},label,11,muted());
                    QString d=i?rearDistance:frontDistance;
                    if(d.isEmpty())d=i?distanceRear:distanceFront;
                    const qreal valueX=r.x()+s(2)+glyph+s(1)+textWidth(label,11)+fs(8);
                    text(p,{valueX,r.y(),std::max(qreal(0),r.right()-s(2)-valueX),r.height()},!showDistance?QStringLiteral("已隐藏"):d.isEmpty()?dash():d,14,ink(),600,Qt::AlignRight|Qt::AlignVCenter);
                }
                QString note=ranging?QStringLiteral("测距已开启，前后视分辨率锁定480p"):QStringLiteral("分辨率选择将在应用后生效");
                text(p,l.note,status.isEmpty()?note:status,12,muted());
            }
            button(p,l.apply,QStringLiteral("应用配置"),QString(),false,true,true);button(p,l.reset,QStringLiteral("恢复默认"));
            text(p,l.footer,!showIntent?QStringLiteral("ADS 2.0.1 · 意图显示已关闭"):drivingHint.isEmpty()?(four?QStringLiteral("ADS 2.0.1 · 四路输入"):QStringLiteral("ADS 2.0.1 · 六路输入")):QStringLiteral("ADS 2.0.1 · ")+drivingHint,12,muted(),QFont::Normal,Qt::AlignCenter);
        }
    }
    p.restore(); // Return to viewport coordinates before painting the popover.
    if(displayPanel) {
        const auto r=displayPanelRect();box(p,r,Qt::white,border(),8);
        text(p,{r.x()+10,r.y()+4,r.width()-20,24},"识别与显示（自动保存）",14,ink(),600);
    }
    for(const auto& c:displayControls())button(p,c.rect,c.label,QString(),false,c.enabled);
    if(navPanel&&!navSelecting){const auto r=navPanelRect();box(p,r,Qt::white,border(),8);
        text(p,{r.x()+10,r.y()+6,r.width()-20,25},"导航屏识别 · 转向与剩余里程",14,ink(),600);
        text(p,{r.x()+10,r.y()+124,r.width()-20,32},navStatus,12,muted());
        text(p,{r.x()+10,r.y()+158,r.width()-20,24},navReadout,12,ink());
        text(p,{r.x()+10,r.y()+186,r.width()-20,34},"圈定完整导航提示（数字、单位、箭头）。来源读数带时间，不代表当前道路距离。",11,muted());}
    if(navSelecting)text(p,{12,44,qreal(viewport_.width()-24),24},"拖框圈定完整导航提示：数字、单位和箭头",14,blue(),600);
    if((navPanel||navSelecting)&&!navRegion.isEmpty()&&!navImageRect().isEmpty()){
        const auto image=navImageRect();p.save();p.setClipRect(viewRect());p.setPen(QPen(QColor("#a855f7"),2,Qt::DashLine));p.setBrush(Qt::NoBrush);
        p.drawRect(QRectF(image.x()+navRegion.x()*image.width()/640,image.y()+navRegion.y()*image.height()/480,navRegion.width()*image.width()/640,navRegion.height()*image.height()/480));p.restore();}
    for(const auto& c:navControls())button(p,c.rect,c.label,QString(),false,c.enabled);
    if(page!=Page::Home) {
        const auto image=cpuImageRect();
        if(!image.isEmpty() && (cpuEnabled||cpuPanel||cpuSelecting)) {
            p.save();p.setClipRect(image,Qt::IntersectClip);p.setBrush(Qt::NoBrush);
            for(int i=0;i<2;++i) {
                const auto r=i?cpuRoad:cpuMark;if(r.isEmpty())continue;
                p.setPen(QPen(QColor(i?"#ff952d":"#19a8ac"),2,Qt::DashLine));
                p.drawRect(QRectF(image.x()+r.x()*image.width()/640,image.y()+r.y()*image.height()/480,
                    r.width()*image.width()/640,r.height()*image.height()/480));
            }
            p.restore();
        }
        if(cpuPanel&&!cpuSelecting) {
            const auto r=cpuPanelRect();box(p,r,Qt::white,border(),8);
            text(p,{r.x()+10,r.y()+6,r.width()-20,25},"CPU道路测距 · 标线在线标定",14,ink(),600);
            text(p,{r.x()+10,r.y()+163,r.width()-20,40},cpuStatus,12,muted());
            text(p,{r.x()+10,r.y()+207,r.width()-20,32},"先圈区域，再选择实际标线长度；无可靠标线时距离未知",11,muted());
        }
        if(cpuSelecting)text(p,{12,44,qreal(viewport_.width()-24),24},cpuSelecting==1?"拖框圈定道路标线，避开地图与仪表区":"拖框圈定可测距的道路区域",14,blue(),600);
        for(const auto& c:cpuControls())button(p,c.rect,c.label,QString(),false,c.enabled);
    }
    if(menu_!=-2&&menuPage_==page) {
        const Menu m=menuLayout(l);p.save();p.setRenderHint(QPainter::Antialiasing);p.setClipRect(viewRect(),Qt::IntersectClip);box(p,m.rect);
        p.setClipRect(m.rect.adjusted(1,1,-1,-1),Qt::IntersectClip);
        for(const Hit& a:m.hits) {
            if(!a.rect.intersects(m.rect))continue;
            p.save();if(!a.enabled)p.setOpacity(.5);
            const qreal size=menu_==-1?s(4):s(3.5);QRectF check(a.rect.x()+s(1.5),a.rect.center().y()-size/2,size,size);
            const bool checked=menu_!=-3&&a.enabled&&(menu_==-1?selectedModels.contains(a.value):channelSelectedModels[menu_].contains(a.value));
            box(p,check,checked?blue():QColor(Qt::white),checked?blue():border(),2);
            if(checked)icon(p,check.adjusted(2,2,-2,-2),"check",Qt::white);
            text(p,a.rect.adjusted(s(1.5)+size+s(2),0,-s(1.5),0),a.label,menu_==-1?14:11,ink());p.restore();
        }
        p.restore();
    }
    // Home 识别对照浮层：11 类目标 + 7 类标线，入口在工具条（F4）。
    if(page==Page::Home&&homeLegend) {
        const QRectF area=legendOverlayRect().translated(0,-offset());
        if(area.isValid())recognition_legend_panel::paint(p,recognition_legend_panel::layout(area,legend));
    }
    if(shortcutHelp) {
        QVector<QPair<QString,QString>> rows;QSet<QString> seen;
        for(const Control& c:controls()) {
            if(seen.contains(c.id))continue;
            const QString key=shortcut_registry::labelFor(c.id);if(key.isEmpty())continue;
            seen.insert(c.id);rows.push_back(qMakePair(c.label,key));
        }
        const qreal rowH=24,rw=std::min<qreal>(720,viewport_.width()-32);
        const int perCol=int((rows.size()+1)/2);
        const QRectF r((viewport_.width()-rw)/2,std::max<qreal>(24,(viewport_.height()-(56+perCol*rowH))/2),
                       rw,56+perCol*rowH);
        p.save();p.setRenderHint(QPainter::Antialiasing);
        box(p,r,QColor(255,255,255,244),border(),10);
        text(p,{r.x()+16,r.y()+12,r.width()-32,26},QStringLiteral("快捷键（? 关闭）"),15,ink(),600);
        const qreal colW=(r.width()-32)/2;
        for(int i=0;i<rows.size();++i) {
            const qreal x=r.x()+16+(i/perCol)*colW,y=r.y()+44+(i%perCol)*rowH;
            text(p,{x,y,colW*.66,rowH},rows[i].first,12,ink(),400);
            text(p,{x+colW*.66,y,colW*.3,rowH},rows[i].second,12,blue(),600);
        }
        p.restore();
    }
    // 相机致命失败：任何页面都给出可辨识的错误码，避免只剩黑屏。
    if(!frameStatus.isEmpty() && frameStatus.startsWith(QStringLiteral("CAMERA ERROR"))) {
        const QRectF vr=viewRect();
        const QRectF banner(vr.left()+vr.width()*.16,vr.top()+vr.height()*.40,
                            vr.width()*.68,vr.height()*.14);
        box(p,banner,QColor(26,10,12,235),QColor("#ff6b6b"),fs(14),3);
        text(p,banner.adjusted(12,8,-12,-8),frameStatus,
             std::max(18,int(fs(40))),QColor("#ff8f8f"),QFont::Bold,Qt::AlignCenter);
    }
}

inline Action Frontend::activate(QPoint point) {
    Action result;result.page=page;if(!viewRect().contains(point))return result;
    for(const auto& c:navControls())if(c.rect.contains(point)){
        if(!c.enabled)return result;result.kind=Action::NavigationSettings;
        result.value=c.id=="nav-toggle"?0:c.id=="nav-region"?1:c.id=="nav-clear"?2:c.id=="nav-source"?3:4;return result;}
    if(navPanel&&!navSelecting&&navPanelRect().contains(point))return result;
    for(const auto& c:displayControls())if(c.rect.contains(point)) {
        menu_=-2;menuScroll_=0;
        result.kind=Action::ViewerControl;result.value=c.id=="display-settings"?4:c.id.section('-',-1).toInt();return result;
    }
    if(displayPanel&&displayPanelRect().contains(point))return result;
    for(const auto& c:cpuControls())if(c.rect.contains(point)) {
        if(!c.enabled)return result;
        result.kind=Action::CpuRanging;
        result.value=c.id=="cpu-toggle"?0:c.id=="cpu-mark"?1:c.id=="cpu-road"?2:
            c.id=="cpu-standard"?3:c.id=="cpu-clear"?4:c.id=="cpu-source"?6:5;
        return result;
    }
    if(cpuPanel&&!cpuSelecting&&cpuPanelRect().contains(point))return result;
    if(menuPage_!=page){menu_=-2;menuScroll_=0;}
    const Layout l=layout();
    if(menu_!=-2&&zoomCamera<0) {
        const Menu m=menuLayout(l);
        if(m.rect.contains(point)) {
            for(const Hit& a:m.hits)if(a.rect.intersected(m.rect).contains(point)) {
                if(a.enabled){
                    if(menu_==-3) { result.kind=Action::LocalVideo;result.value=a.value;menu_=-2;return result; }
                    result.kind=Action::Model;result.camera=a.camera;result.value=a.value;
                    QSet<int>& selected=menu_==-1?selectedModels:channelSelectedModels[menu_];
                    if(menu_==-1||modelSupported[menu_]) {
                        if(selected.contains(a.value))selected.remove(a.value);else selected.insert(a.value);
                    }
                }
                // These are draft edits; the host confirms or rejects hardware binding.
                return result;
            }
            return result;
        }
    }
    const QPointF local=QPointF(point)+QPointF(0,zoomCamera>=0?0:offset());
    // Home 识别对照浮层：点浮层或按钮以外的地方先收起，再按正常命中继续处理。
    if(page==Page::Home&&homeLegend&&!l.homeLegendButton.contains(local)&&
       !legendOverlayRect().contains(local))homeLegend=false;
    // Specific controls must win over Six's entire-card zoom hit target.
    for(const Hit& a:l.hits) {
        if(!a.rect.contains(local))continue;
        if(a.id=="hdmi-panorama") {
            result.kind=Action::HdmiPanorama;
            result.camera=-1;
            result.value=hdmiPanoramaActive?0:1;
            hdmiPanoramaActive=!hdmiPanoramaActive;
            menu_=-2;
            return result;
        }
        if(!a.enabled){menu_=-2;return result;}
        if(a.internal==1) {
            const int next=a.camera;
            menu_=menu_==next?-2:next;menuPage_=page;menuScroll_=0;return result;
        }
        menu_=-2;menuScroll_=0;
        if(a.internal==5) {homeLegend=!homeLegend;return result;}
        if(a.internal==7) {homeToolsPanel=!homeToolsPanel;return result;}
        if(a.internal==2) {
            const std::array<int,6> defaults{{480,480,240,240,480,480}};
            for(int c=0;c<6;++c)if(resolutionSupported[c])resolution[c]=defaults[c];
            for(QSet<int>& selected:channelSelectedModels)selected.clear();
            // Reset is a local draft edit, not an Apply or a hardware success.
            return result;
        }
        if(a.internal==3) {
            if(zoomCamera>=0){zoomCamera=-1;result.kind=Action::Zoom;result.camera=-1;result.value=-1;return result;}
            page=Page::Home;result.kind=Action::Navigate;result.page=page;return result;
        }
        if(a.internal==4) {
            page=static_cast<Page>(a.value);zoomCamera=-1;result.kind=Action::Navigate;result.page=page;return result;
        }
        result.kind=a.kind;result.camera=a.camera;result.value=a.value;
        switch(a.kind) {
        case Action::Resolution: resolution[a.camera]=a.value;break;
        case Action::Confidence:
            confidence=std::max(.10,std::min(.90,std::round((confidence+a.value/100.0)*100)/100));
            result.value=int(std::round(confidence*100));break;
        case Action::Zoom:zoomCamera=a.camera;break;
        case Action::Ranging:
            ranging=a.value!=0;
            if(ranging)for(int c=0;c<6;++c)if(rangingLocked(c))resolution[c]=480;
            break;
        case Action::Panorama:panorama=a.value!=0;zoomCamera=-1;break;
        case Action::HdmiPanorama:hdmiPanoramaActive=a.value==0;break;
        case Action::Lamp: // Demo interaction explicitly present in original HTML.
            break; // Physical detections are the only signal evidence in production.
        case Action::TagScroll:break;
        default:break;
        }
        return result;
    }
    menu_=-2;return result;
}

#define EXACT_UI_CHECK(condition) do { if(!(condition)) { fprintf(stderr,"[exact-ui-selftest] FAIL line=%d page=%d viewport=%dx%d\n",__LINE__,int(f.page),f.viewport().width(),f.viewport().height()); return false; } } while(0)
inline bool Frontend::selfTest() {
    for(QSize size:{QSize(1920,1080),QSize(1280,720),QSize(720,1280)}) {
        Frontend f;f.setViewport(size);f.availableModels=QStringList{QStringLiteral("actual.rknn"),QStringLiteral("second.rknn")};
        EXACT_UI_CHECK(f.page==Page::Home);
        // Home 主界面结构：主画面/统计/下一步行动/工具条不重叠，七个驾驶控件的
        // 命中矩形与绘制矩形同源（都来自 layout()）。
        {
            const auto home=f.layout();
            if(home.homeFrame.isEmpty()||!home.homeVideo.contains(home.homeFrame))return false;
            if(home.homeStats.intersects(home.homeVideo)||home.homePredict.intersects(home.homeStats)||
               home.homeTools.intersects(home.homePredict))return false;
            if(f.videoTiles().size()!=1||f.videoTiles()[0].camera!=0)return false;
            const QString ids[7]={QStringLiteral("drive-go"),QStringLiteral("drive-stop"),
                QStringLiteral("drive-lane-0"),QStringLiteral("drive-lane-1"),QStringLiteral("drive-lane-2"),
                QStringLiteral("drive-change-left"),QStringLiteral("drive-change-right")};
            for(int i=0;i<7;++i) {
                const QRectF rect=f.controlRect(ids[i]);
                if(rect.isEmpty()||!f.viewRect().contains(rect))return false;
                const QRectF card=i<2?home.homeDrive:i<5?home.homeLane:home.homeChange;
                if(!card.contains(rect))return false;
                const auto action=f.activate(rect.center().toPoint());
                if(action.kind!=Action::DriveControl||action.value!=i)return false;
            }
            // 视图切换与输入源入口保留，动作指向既有页面。
            if(f.activate(f.controlRect("home-view-four").center().toPoint()).page!=Page::Four)return false;
            f.page=Page::Home;
            if(f.activate(f.controlRect("home-source-hdmi").center().toPoint()).page!=Page::Hdmi)return false;
            f.page=Page::Home;
        }
        // 窄屏/竖屏会把这一组控件整组收起，此时跳过菜单断言（快捷键仍可用）。
        f.homeToolsPanel=true;
        if(!f.controlRect("model-dropdown-btn").isEmpty()) {
        f.activate(f.controlRect("model-dropdown-btn").center().toPoint());
        const Menu homeMenu=f.menuLayout(f.layout());
        if(homeMenu.hits.size()!=6||!f.viewRect().contains(homeMenu.rect))return false;
        for(int i=1;i<homeMenu.hits.size();++i)
            if(std::abs(homeMenu.hits[i].rect.y()-homeMenu.hits[i-1].rect.bottom()-f.s(1))>.00001)return false;
        f.activate(f.controlRect("model-dropdown-btn").center().toPoint());
        }
        f.homeToolsPanel=false;
        for(Page target:{Page::Six,Page::Four,Page::Hdmi}) {
            f.page=Page::Home;f.ranging=false;f.panorama=false;f.selectedModels.clear();
            for(QSet<int>& selected:f.channelSelectedModels)selected.clear();
            const QString entry=target==Page::Six?QStringLiteral("home-view-six"):
                target==Page::Four?QStringLiteral("home-view-four"):QStringLiteral("home-source-hdmi");
            Action a=f.activate(f.controlRect(entry).center().toPoint());
            if(a.kind!=Action::Navigate||f.page!=target||a.page!=target)return false;
            const Layout l=f.layout();
            if(f.contentHeight()<size.height())return false;
            if(target==Page::Hdmi) {
                if(l.statusBar.isEmpty()||!l.lamps.isEmpty()||!l.leftLamp.isEmpty()||!l.rightLamp.isEmpty())return false;
                if(!l.hdmi.contains(l.statusBar)||l.statusBar.right()>=l.rightTop.left())return false;
                if(std::abs(l.statusBar.width()/l.statusBar.height()-status_bar::panelWidth/status_bar::panelHeight)>.001)return false;
                if(l.rightTop.width()<120||l.rightBottom.width()!=l.rightTop.width())return false;
                if(!l.hdmi.contains(l.rightTop)||!l.hdmi.contains(l.rightBottom))return false;
                if(l.rightTop.intersects(l.rightBottom)||l.statusBar.intersects(l.driving)||l.driving.intersects(l.rightBottom))return false;
                if(!f.controlRect("legend-up").isEmpty()||!f.controlRect("legend-down").isEmpty())return false;
                const auto legendLayout=recognition_legend_panel::layout(l.rightTop,f.legend);
                if(legendLayout.entries.size()!=18)return false;
                for(const auto& entry:legendLayout.entries)
                    if(entry.text.isEmpty()||!l.rightTop.contains(entry.rect))return false;
                const auto viewport=f.hdmiVideoRect();
                if(viewport.isEmpty()||viewport.intersects(l.statusBar)||viewport.intersects(l.driving)||!l.hdmi.contains(viewport))return false;
                if(!f.videoTiles().isEmpty())return false;
                for(int i=0;i<7;++i) {
                    const QString id=QStringList{"drive-go","drive-stop","drive-lane-0","drive-lane-1","drive-lane-2","drive-change-left","drive-change-right"}[i];
                    const auto rect=f.controlRect(id);
                    if(rect.isEmpty()||!f.viewRect().contains(rect))return false;
                    if(std::abs(rect.width()-rect.height())>.001||!f.drivingControlsRect().contains(rect))return false;
                    if(rect.intersects(f.controlRect("rule-light-count"))||rect.intersects(f.controlRect("rule-light-region")))return false;
                    const auto action=f.activate(rect.center().toPoint());
                    if(action.kind!=Action::DriveControl||action.value!=i)return false;
                }
                f.applyDriveControl(0,false);if(!f.drivingRequested)return false;
                f.applyDriveControl(5,false);if(f.changeRequest!=-1)return false;
                f.applyDriveControl(4,false);if(f.assumedLane!=1||f.changeRequest!=0)return false;
                f.applyDriveControl(0,true);if(!f.drivingRequested)return false;
                f.applyDriveControl(1,false);if(f.driveWarningUntil!=0)return false;
            } else {
                const QVector<VideoTile> ts=f.videoTiles();EXACT_UI_CHECK(ts.size()==(target==Page::Six?6:4));
                EXACT_UI_CHECK(f.maximumScroll()==0&&f.scrollOffset()==0&&f.contentHeight()==size.height());
                const int expectedCols=target==Page::Four?2:(size.width()>=1024?3:2);
                if(size.width()==720&&target==Page::Six)EXACT_UI_CHECK(l.tiles.size()==6);
                for(int i=0;i<l.tiles.size();++i) {
                    const Tile& t=l.tiles[i];
                    const Tile& column=l.tiles[i%expectedCols];
                    const Tile& row=l.tiles[i/expectedCols*expectedCols];
                    EXACT_UI_CHECK(std::abs(t.card.x()-column.card.x())<.01&&std::abs(t.card.y()-row.card.y())<.01);
                    EXACT_UI_CHECK(f.viewRect().contains(t.card)&&t.card.contains(t.title)&&t.card.contains(t.video)&&t.card.contains(t.resFrame)&&t.card.contains(t.modelLabel)&&t.card.contains(t.model));
                    EXACT_UI_CHECK(t.title.bottom()<=t.video.top());
                    EXACT_UI_CHECK(t.video.bottom()<=t.resFrame.top());
                    EXACT_UI_CHECK(std::abs(t.resFrame.center().y()-t.modelLabel.center().y())<.01);
                    EXACT_UI_CHECK(std::abs(t.resFrame.center().y()-t.model.center().y())<.01);
                    EXACT_UI_CHECK(t.resFrame.right()<=t.modelLabel.left());
                    EXACT_UI_CHECK(t.modelLabel.right()<=t.model.left());
                    EXACT_UI_CHECK(t.model.width()>=f.fs(72)-.01);
                    EXACT_UI_CHECK(t.resFrame.height()>=f.fs(22)-.01);
                    EXACT_UI_CHECK(t.video.width()>0&&t.video.height()>0);
                    for(const QRectF& option:t.options)EXACT_UI_CHECK(t.resFrame.contains(option));
                    for(int j=0;j<i;++j)EXACT_UI_CHECK(!t.card.intersects(l.tiles[j].card));
                }
                EXACT_UI_CHECK(f.viewRect().contains(l.toolbar)&&f.viewRect().contains(l.footer)&&!l.tiles.last().card.intersects(l.toolbar)&&!l.toolbar.intersects(l.footer));
                QVector<QRectF> actionRects{l.rangeButton,l.front,l.rear,l.apply,l.reset,l.note};
                for(int i=0;i<actionRects.size();++i) {
                    EXACT_UI_CHECK(!actionRects[i].isEmpty()&&l.toolbar.contains(actionRects[i]));
                    EXACT_UI_CHECK(std::abs(actionRects[i].center().y()-l.toolbar.center().y())<.01);
                    for(int j=0;j<i;++j)EXACT_UI_CHECK(!actionRects[i].intersects(actionRects[j]));
                }
                if(f.panorama) {
                    for(const QRectF& r:{l.rangeButton,l.front,l.rear,l.note})EXACT_UI_CHECK(r.isEmpty());
                }
                for(const Control& c:f.controls())EXACT_UI_CHECK(!c.rect.isEmpty()&&f.viewRect().contains(c.rect));
                const int four[]{0,4,2,3};
                for(int i=0;i<ts.size();++i) {
                    if(ts[i].camera!=(target==Page::Six?i:four[i]))return false;
                    if(ts[i].rect.x()<0||ts[i].rect.right()>size.width()||ts[i].rect.width()<=0||ts[i].rect.height()<=0)return false;
                    for(int j=0;j<i;++j)if(ts[i].rect.intersects(ts[j].rect))return false;
                }
                f.hd[0]=false;f.frameRates[0]=QStringLiteral("27.5fps");f.sensorName=QStringLiteral("REAL_SENSOR");
                if(!f.zoomInfo(0).contains(QStringLiteral("480p"))||!f.zoomInfo(0).contains(QStringLiteral("27.5fps"))||!f.zoomInfo(0).contains(QStringLiteral("REAL_SENSOR")))return false;
                f.hd[0]=true;
                if(!f.zoomInfo(0).contains(QStringLiteral("720p"))||f.zoomInfo(0).contains(QStringLiteral("480p")))return false;
                const int oldScroll=f.scrollOffset();
                if(target==Page::Four)for(int i=0;i<ts.size();++i) {
                    if(f.channelLabel(four[i])!=QStringLiteral("CH%1").arg(i+1,2,10,QChar('0')))return false;
                    a=f.activate(ts[i].rect.center().toPoint());
                    if(a.kind!=Action::Zoom||a.camera!=four[i]||f.zoomCamera!=four[i]||
                       f.videoTiles().size()!=1||f.videoTiles()[0].camera!=four[i])return false;
                    a=f.activate(f.controlRect("zoom-back").center().toPoint());
                    if(a.kind!=Action::Zoom||f.zoomCamera!=-1||f.scrollOffset()!=oldScroll)return false;
                }
                a=f.activate(ts[0].rect.center().toPoint());
                if(a.kind!=Action::Zoom||f.zoomCamera!=0||f.videoTiles().size()!=1)return false;
                if(!f.viewRect().contains(f.videoTiles()[0].rect))return false;
                a=f.activate(f.controlRect("zoom-back").center().toPoint());
                if(a.kind!=Action::Zoom||f.zoomCamera!=-1||f.page!=target||f.scrollOffset()!=oldScroll)return false;
                f.scroll(100000);if(f.scrollOffset()!=f.maximumScroll())return false;
                if(!f.viewRect().contains(f.controlRect("apply-config")))return false;
                a=f.activate(f.controlRect("apply-config").center().toPoint());if(a.kind!=Action::Apply)return false;
                f.resolution[0]=720;f.resolution[1]=720;f.resolution[4]=720;f.resolution[5]=720;
                a=f.activate(f.controlRect("toggle-ranging").center().toPoint());
                if(a.kind!=Action::Ranging||!f.ranging)return false;
                for(int c=0;c<6;++c)if(rangingLocked(c)&&f.resolution[c]!=480)return false;
                f.scroll(-100000);if(f.scrollOffset()!=0)return false;
                for(const Control& c:f.controls())if(c.id.startsWith(QStringLiteral("res-ch"))) {
                    const int camera=c.id.mid(6,c.id.indexOf(QChar('-'),6)-6).toInt()-1;
                    const bool enabled=f.resolutionSupported[camera]&&!(f.ranging&&rangingLocked(camera));
                    if(c.enabled!=enabled)return false;
                    if(!enabled&&f.viewRect().contains(c.rect.center())&&f.activate(c.rect.center().toPoint()).kind==Action::Resolution)return false;
                }
                if(!f.viewRect().contains(f.controlRect("model-ch1")))return false;
                f.activate(f.controlRect("model-ch1").center().toPoint());
                const Menu channelMenu=f.menuLayout(f.layout());
                if(channelMenu.hits.size()!=6||!f.viewRect().contains(channelMenu.rect))return false;
                for(int i=1;i<channelMenu.hits.size();++i)
                    if(std::abs(channelMenu.hits[i].rect.y()-channelMenu.hits[i-1].rect.bottom()-f.s(1))>.00001)return false;
                f.modelSupported[0]=true;
                a=f.activate(f.controlRect("installed-model-0").center().toPoint());
                if(a.kind!=Action::Model||a.camera!=0||!f.channelSelectedModels[0].contains(0)||f.channelModelSummary(0)!=QStringLiteral("actual.rknn"))return false;
                a=f.activate(f.controlRect("installed-model-1").center().toPoint());
                if(a.kind!=Action::Model||f.channelSelectedModels[0].size()!=2||f.channelModelSummary(0)!=QStringLiteral("已选 2 个"))return false;
                f.activate(f.controlRect("installed-model-0").center().toPoint());
                if(f.channelSelectedModels[0].contains(0)||f.channelModelSummary(0)!=QStringLiteral("second.rknn"))return false;
                f.activate(f.controlRect("model-ch1").center().toPoint());
                if(target==Page::Six) {
                    f.activate(f.controlRect("model-ch2").center().toPoint());
                    a=f.activate(f.controlRect("installed-model-0").center().toPoint());
                    if(a.kind!=Action::Model||a.camera!=1||a.value!=0||!f.channelSelectedModels[1].isEmpty())return false;
                    f.activate(f.controlRect("model-ch2").center().toPoint());
                }
                f.scroll(100000);
                f.activate(f.controlRect("reset-res").center().toPoint());
                for(const QSet<int>& selected:f.channelSelectedModels)if(!selected.isEmpty())return false;
                f.scroll(-100000);
                if(target==Page::Four) {
                    f.panoramaSupported=true;
                    a=f.activate(f.controlRect("toggle-panorama").center().toPoint());
                    if(a.kind!=Action::Panorama||!f.panorama||!f.videoTiles().isEmpty()||f.panoramaRect().isEmpty())return false;
                    const QRectF pr=f.panoramaRect();if(std::abs(pr.height()/pr.width()-9.0/16)>.00001)return false;
                    if(!f.controlRect("toggle-ranging").isEmpty())return false;
                    f.activate(f.controlRect("toggle-panorama").center().toPoint());
                }
            }
            f.scroll(-100000);
            a=f.activate(f.controlRect("back-home").center().toPoint());if(a.kind!=Action::Navigate||f.page!=Page::Home)return false;
        }
        // 末尾这组断言假定次行控件可见，先切回横屏视口（竖屏时该组整组收起）。
        f.setViewport(QSize(1920,1080));
        f.homeToolsPanel=true;
        f.page=Page::Home;f.confidence=.1;
        if(f.activate(f.controlRect("conf-minus").center().toPoint()).kind!=Action::None)return false;
        f.availableModels=QStringList{QStringLiteral("actual.rknn"),QStringLiteral("second.rknn")};
        f.activate(f.controlRect("model-dropdown-btn").center().toPoint());
        if(f.activate(f.controlRect("category-0").center().toPoint()).kind!=Action::None)return false;
        const Action model=f.activate(f.controlRect("installed-model-0").center().toPoint());
        if(model.kind!=Action::Model||model.value!=0||model.camera!=-1||f.activeModel!=-1||!f.selectedModels.contains(0))return false;
        const Action second=f.activate(f.controlRect("installed-model-1").center().toPoint());
        if(second.kind!=Action::Model||f.selectedModels.size()!=2||f.homeModelSummary()!=QStringLiteral("已选 2 个模型"))return false;
        f.activate(f.controlRect("installed-model-0").center().toPoint());
        if(f.selectedModels.contains(0)||!f.selectedModels.contains(1))return false;
    }
    return true;
}
} // namespace exact_ui
