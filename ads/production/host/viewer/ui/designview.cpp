#include "designview.h"
#include "../six_profile.h"
#include <QFile>
#include <QDir>
#include <QCoreApplication>
#include <QElapsedTimer>
#include <QFontDatabase>
#include <QFontMetricsF>
#include <QGraphicsObject>
#include <QGraphicsSceneMouseEvent>
#include <QGraphicsProxyWidget>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLinearGradient>
#include <QMouseEvent>
#include <QPainter>
#include <QPainterPath>
#include <QPixmap>
#include <QPushButton>
#include <QResizeEvent>
#include <QRegularExpression>
#include <QScreen>
#include <QSet>
#include <QStyleOptionGraphicsItem>
#include <cmath>
#include <algorithm>
#include <functional>

namespace {
enum BindingItemRole {
    NodeIdRole = Qt::UserRole + 101,
    StateBindingRole = Qt::UserRole + 102,
    StateInkRole = Qt::UserRole + 103,
    DisplayTextRole = Qt::UserRole + 104
};

// 设计节点的“动态”判定：自身外观是否会随绑定/感知/交互变化。
// 必须覆盖所有运行期写路径（applyPerception / refreshBindingVisuals /
// setNodeText / setNodeImage / 拖动），宁可多判动态，也不要把会变的内容烘焙成死图。
bool textMayBeRewritten(const QString &text) {
    if (text.isEmpty()) return false;
    // 类别标签是静态文字；标签与计数的配对在页面加载时完成。
    static const QSet<QString> categoryLabels{
        QStringLiteral("机动车"),QStringLiteral("车辆"),QStringLiteral("行人"),
        QStringLiteral("自行车"),QStringLiteral("非机动车"),QStringLiteral("公交车"),
        QStringLiteral("摩头车"),QStringLiteral("摩托车"),QStringLiteral("车道线"),
        QStringLiteral("障碍物")};
    if (categoryLabels.contains(text)) return false;
    // 与 applyPerception 中的通用文本替换规则保持一致。
    static const QVector<QRegularExpression> patterns{
        QRegularExpression(QStringLiteral("^融合目标\\s*\\d+\\s*个$")),
        QRegularExpression(QStringLiteral("^\\d+(?:\\.\\d+)?\\s*米$")),
        QRegularExpression(QStringLiteral("^\\d+\\s*×\\s*\\d+.*帧")),
        QRegularExpression(QStringLiteral("^\\S+\\s*\\d+\\s*·\\s*\\d+%$")),
        QRegularExpression(QStringLiteral("^\\d{1,3}$")),
        QRegularExpression(QStringLiteral("%"))};
    for (const auto &pattern : patterns)
        if (pattern.match(text).hasMatch()) return true;
    return text == QStringLiteral("已同步") || text == QStringLiteral("已连接") ||
        text == QStringLiteral("绿灯") || text == QStringLiteral("红灯") ||
        text == QStringLiteral("黄灯") || text == QStringLiteral("直行允许");
}

bool nodeOwnDynamic(const QJsonObject &node) {
    if (!node.value("action").toString().isEmpty()) return true;
    if (!node.value("binding").toString().isEmpty()) return true;
    if (!node.value("interaction").toObject().isEmpty()) return true;
    if (!node.value("stateBinding").toString().isEmpty()) return true;
    if (node.value("type").toString() == QStringLiteral("SWITCH")) return true;
    if (node.value("draggable").toBool()) return true;
    static const QSet<QString> mutableNames{
        QStringLiteral("融合目标数"),QStringLiteral("目标数量")};
    if (mutableNames.contains(node.value("name").toString())) return true;
    return node.value("type").toString() == QStringLiteral("TEXT") &&
        textMayBeRewritten(node.value("text").toString());
}

bool staticLayerBakesVectors() {
    static const bool enabled=!qEnvironmentVariableIsSet("ADS_STATIC_LAYERS_BAKE_VECTORS")||
        qEnvironmentVariableIntValue("ADS_STATIC_LAYERS_BAKE_VECTORS")!=0;
    return enabled;
}
bool axisAlignedTransform(const QJsonObject &node) {
    const auto t=node.value("transform").toObject();
    return qFuzzyCompare(t.value("m00").toDouble(1),1.0)&&
        qFuzzyCompare(t.value("m11").toDouble(1),1.0)&&
        qFuzzyIsNull(t.value("m01").toDouble(0))&&qFuzzyIsNull(t.value("m10").toDouble(0));
}
// 合并后的静态图层：一段连续静态 z 子树一次性合成，场景只做一次图片绘制。
class StaticLayerItem final : public QGraphicsItem {
public:
    StaticLayerItem(const QRectF &rect, const QImage &image)
        : rect_(rect), pixmap_(QPixmap::fromImage(image)) {
        setAcceptedMouseButtons(Qt::NoButton);
    }
    QRectF boundingRect() const override { return rect_; }
    void paint(QPainter *p, const QStyleOptionGraphicsItem *, QWidget *) override {
        if (pixmap_.isNull()) return;
        // 烘焙分辨率与当前场景输出一致时按 1:1 拷贝，避免每帧整幅重采样。
        const QTransform world = p->worldTransform();
        const qreal scale = std::hypot(world.m11(), world.m12());
        const bool exact = qAbs(rect_.width() * scale - pixmap_.width()) < 0.5 &&
            qAbs(rect_.height() * scale - pixmap_.height()) < 0.5;
        p->setRenderHint(QPainter::SmoothPixmapTransform, !exact);
        p->drawPixmap(rect_, pixmap_, QRectF(pixmap_.rect()));
    }
private:
    QRectF rect_;
    QPixmap pixmap_;
};

QJsonValue resolveTokens(const QJsonValue &value,const QJsonObject &tokens) {
    if(value.isString()&&value.toString().startsWith("@token/"))return tokens.value(value.toString().mid(7));
    if(value.isArray()){QJsonArray out;for(const auto &v:value.toArray())out.append(resolveTokens(v,tokens));return out;}
    if(value.isObject()){auto out=value.toObject();for(auto it=out.begin();it!=out.end();++it)it.value()=resolveTokens(it.value(),tokens);return out;}
    return value;
}
QColor color(const QJsonValue &value, double opacity = 1) {
    if(value.isString()) {
        QColor c(value.toString());
        c.setAlphaF(qBound(0.,c.alphaF()*opacity,1.));
        return c;
    }
    const auto c=value.toObject();
    return QColor::fromRgbF(qBound(0., c.value("r").toDouble(), 1.),
        qBound(0., c.value("g").toDouble(), 1.), qBound(0., c.value("b").toDouble(), 1.),
        qBound(0., c.value("a").toDouble(1) * opacity, 1.));
}
QPainterPath makePath(const QJsonObject &g) {
    QPainterPath p;
    p.setFillRule(g.value("rule")=="ODD" ? Qt::OddEvenFill : Qt::WindingFill);
    for (const auto &value : g.value("commands").toArray()) {
        const auto c=value.toObject(); const auto t=c.value("type").toString();
        const double x=c.value("x").toDouble(),y=c.value("y").toDouble();
        if(t=="M") p.moveTo(x,y);
        else if(t=="L") p.lineTo(x,y);
        else if(t=="C") p.cubicTo(c.value("c1x").toDouble(),c.value("c1y").toDouble(),
            c.value("c2x").toDouble(),c.value("c2y").toDouble(),x,y);
        else if(t=="Z") p.closeSubpath();
    }
    return p;
}
QBrush paintBrush(const QJsonObject &paint, const QRectF &rect) {
    const auto type=paint.value("type").toString();
    const auto alpha=paint.value("opacity").toDouble(1);
    if(type=="SOLID")return color(paint.value("color"),alpha);
    if(type.startsWith("GRADIENT")) {
        // Approximate unsupported Figma gradient handles using the node bounds.
        QLinearGradient gradient(rect.topLeft(),rect.bottomRight());
        for(const auto &v:paint.value("stops").toArray()) {
            const auto stop=v.toObject();
            gradient.setColorAt(qBound(0.,stop.value("position").toDouble(),1.),color(stop.value("color"),alpha));
        }
        return gradient;
    }
    return Qt::NoBrush;
}
QString designRoot() {
        const QStringList candidates{qEnvironmentVariable("ADS_DESIGN_DIR"),
            QCoreApplication::applicationDirPath()+QStringLiteral("/assets"),QStringLiteral("assets")};
        for (const QString &candidate : candidates)
            if (!candidate.isEmpty() && (QFile::exists(candidate + QStringLiteral("/design.json"))||QFile::exists(candidate+QStringLiteral("/manifest.json")))) return candidate;
        return QString();
}
QString fontFamily() {
    const auto families=QFontDatabase().families();
    for(const QString &f: {QStringLiteral("Noto Sans SC"),QStringLiteral("Noto Sans CJK SC"),
                          QStringLiteral("Microsoft YaHei"),QStringLiteral("WenQuanYi Micro Hei")})
        if(families.contains(f))return f;
    return QStringLiteral("sans-serif");
}

QJsonObject transform(double x, double y) {
    QJsonObject result;
    result["m00"]=1.0; result["m01"]=0.0; result["m02"]=x;
    result["m10"]=0.0; result["m11"]=1.0; result["m12"]=y;
    return result;
}

QJsonObject solidPaint(const QString &color) {
    QJsonObject paint;
    paint["type"]=QStringLiteral("SOLID");
    paint["color"]=color;
    paint["opacity"]=1.0;
    paint["visible"]=true;
    return paint;
}

// 前后视测距开关直接挂在原稿面板内，不修改导出的 design.json。
QJsonObject rangeSwitchNode(const QString &pageKey) {
    const QString prefix=QStringLiteral("runtime:range-toggle:")+pageKey;
    QJsonObject label;
    label["id"]=prefix+QStringLiteral(":label");
    label["name"]=QStringLiteral("测距");
    label["type"]=QStringLiteral("TEXT");
    label["size"]=QJsonObject{{"x",40.0},{"y",28.0}};
    label["transform"]=transform(0,0);
    label["visible"]=true; label["opacity"]=1.0;
    label["fills"]=QJsonArray{solidPaint(QStringLiteral("#b7d2d2"))};
    label["strokes"]=QJsonArray();
    label["text"]=QStringLiteral("测距");
    label["fontSize"]=12.0;
    label["fontFamily"]=QStringLiteral("Noto Sans SC");
    label["fontStyle"]=QStringLiteral("Medium");
    label["align"]=QStringLiteral("LEFT");
    label["baseline"]=18.0; label["lineHeight"]=20.0; label["letterSpacing"]=0.0; label["lines"]=1;
    label["children"]=QJsonArray();

    QJsonObject track;
    track["id"]=prefix+QStringLiteral(":track");
    track["name"]=QStringLiteral("滑动开关");
    track["type"]=QStringLiteral("SWITCH");
    track["size"]=QJsonObject{{"x",38.0},{"y",22.0}};
    track["transform"]=transform(44,3);
    track["visible"]=true; track["opacity"]=1.0;
    track["radius"]=11.0;
    track["onColor"]=QStringLiteral("#29dfc8");
    track["offColor"]=QStringLiteral("#0c1a22");
    track["onBorderColor"]=QStringLiteral("#29dfc8");
    track["offBorderColor"]=QStringLiteral("#27444f");
    track["onKnobColor"]=QStringLiteral("#08141d");
    track["offKnobColor"]=QStringLiteral("#8ba5b1");
    track["fills"]=QJsonArray(); track["strokes"]=QJsonArray();
    track["children"]=QJsonArray();

    QJsonObject variants;
    const QStringList switchStates{QStringLiteral("on"),QStringLiteral("off"),QStringLiteral("disabled")};
    for(const auto &state:switchStates) {
        QJsonObject variant;
        variant["opacity"]=state==QStringLiteral("disabled")?0.45:1.0;
        variants[state]=variant;
    }
    QJsonObject toggle;
    toggle["id"]=prefix;
    toggle["name"]=QStringLiteral("测距开关");
    toggle["type"]=QStringLiteral("FRAME");
    toggle["size"]=QJsonObject{{"x",84.0},{"y",28.0}};
    // 放在面板标题与右侧状态文字之间，保持 348 宽面板的左右留白。
    toggle["transform"]=transform(144,6);
    toggle["visible"]=true; toggle["opacity"]=1.0;
    toggle["fills"]=QJsonArray(); toggle["strokes"]=QJsonArray();
    toggle["radius"]=0.0; toggle["clip"]=false;
    toggle["action"]=QStringLiteral("range:toggle");
    toggle["interaction"]=QJsonObject{{"mode",QStringLiteral("toggle")},
        {"stateBinding",QStringLiteral("range.state")},
        {"defaultState",QStringLiteral("off")},
        {"variants",variants}};
    toggle["children"]=QJsonArray{label,track};
    return toggle;
}

// Four-page exported indices are display slots, not physical camera IDs.
// Normalize every binding together so video, status and results share an owner.
QJsonObject bindFourCameras(QJsonObject node) {
    static const int cameras[4]={0,4,2,3};
    const int slot=node.value("channelIndex").toInt(-1);
    if(slot>=0 && slot<4) {
        node["channelIndex"]=cameras[slot];
        if(node.value("binding").toString()==QStringLiteral("channel.number")) {
            node.remove("binding");
            node["text"]=QStringLiteral("CH %1").arg(slot+1,2,10,QChar('0'));
        }
    }
    auto children=node.value("children").toArray();
    for(int i=0;i<children.size();++i)children[i]=bindFourCameras(children[i].toObject());
    if(node.contains("children"))node["children"]=children;
    return node;
}

// Range cards independently use physical stereo owners C1/C5.
void bindRangeCard(QJsonObject &node,int camera) {
    if(node.contains("channelIndex"))node["channelIndex"]=camera;
    if(node.value("name").toString()==QStringLiteral("测距辅助信息")) {
        auto status=rangeSwitchNode(QStringLiteral("status")).value("children").toArray().first().toObject();
        status["id"]=node.value("id").toString()+QStringLiteral(":runtime-status");
        status["binding"]=QStringLiteral("channel.rangeStatus");status["channelIndex"]=camera;
        status["size"]=QJsonObject{{"x",320.0},{"y",12.0}};
        status["fontSize"]=9.0;status["baseline"]=9.0;status["lineHeight"]=12.0;
        status["text"]=QString();node["children"]=QJsonArray{status};
        return;
    }
    auto children=node.value("children").toArray();
    for(int i=0;i<children.size();++i){auto child=children[i].toObject();bindRangeCard(child,camera);children[i]=child;}
    node["children"]=children;
}

bool attachRangeSwitch(QJsonObject &node,const QString &pageKey) {
    if(node.value("role").toString()==QStringLiteral("panel") &&
       node.value("name").toString()==QStringLiteral("前后视测距")) {
        auto children=node.value("children").toArray();
        for(int i=0;i<children.size();++i) {
            auto child=children[i].toObject();
            const auto name=child.value("name").toString();
            if(name==QStringLiteral("前视测距信息"))bindRangeCard(child,0);
            else if(name==QStringLiteral("后视测距信息"))bindRangeCard(child,4);
            children[i]=child;
        }
        const QString id=QStringLiteral("runtime:range-toggle:")+pageKey;
        for(const auto &value:children)
            if(value.toObject().value("id").toString()==id){node["children"]=children;return true;}
        children.append(rangeSwitchNode(pageKey));
        node["children"]=children;
        return true;
    }
    auto children=node.value("children").toArray();
    for(int i=0;i<children.size();++i) {
        auto child=children[i].toObject();
        if(attachRangeSwitch(child,pageKey)){children[i]=child;node["children"]=children;return true;}
    }
    return false;
}

bool findActionPlacement(const QJsonObject &node,const QString &action,qreal &x,qreal &y) {
    if(node.value("action").toString()==action) {
        const auto placement=node.value("transform").toObject();
        x=placement.value("m02").toDouble();y=placement.value("m12").toDouble();
        return true;
    }
    for(const auto &value:node.value("children").toArray())
        if(findActionPlacement(value.toObject(),action,x,y))return true;
    return false;
}

QJsonObject normalizeNavigation(QJsonObject node,qreal multiX,qreal multiY) {
    QJsonArray children;
    for(const auto &value:node.value("children").toArray()) {
        auto child=value.toObject();
        const QString action=child.value("action").toString();
        if(action==QStringLiteral("page:multi"))continue;
        if(action==QStringLiteral("page:four")) {
            child["name"]=QStringLiteral("4路视图");
            child["transform"]=transform(multiX,multiY);
            auto labels=child.value("children").toArray();
            for(int i=0;i<labels.size();++i) {
                auto label=labels[i].toObject();
                if(label.value("type").toString()==QStringLiteral("TEXT")) {
                    label["name"]=QStringLiteral("4路视图");
                    label["text"]=QStringLiteral("4路视图");
                    labels[i]=label;
                }
            }
            child["children"]=labels;
        }
        children.append(normalizeNavigation(child,multiX,multiY));
    }
    // Removing the old multi page leaves one button-width of empty space at
    // the right. Translate the navigation row as a group; artwork and hit areas
    // share the same node transform.
    const double width=node.value("size").toObject().value("x").toDouble();
    QVector<int> navigation;
    double right=0;
    bool hasFour=false;
    for(int i=0;i<children.size();++i) {
        const auto child=children[i].toObject();
        const auto action=child.value("action").toString();
        const auto placement=child.value("transform").toObject();
        if(!action.startsWith(QStringLiteral("page:"))||
           qAbs(placement.value("m12").toDouble()-multiY)>0.01)continue;
        navigation.append(i);
        hasFour|=action==QStringLiteral("page:four");
        right=qMax(right,placement.value("m02").toDouble()+
            child.value("size").toObject().value("x").toDouble());
    }
    if(hasFour&&navigation.size()==4&&width>0) {
        const double offset=width-24-right;
        for(int i:navigation) {
            auto child=children[i].toObject();
            auto placement=child.value("transform").toObject();
            placement["m02"]=placement.value("m02").toDouble()+offset;
            child["transform"]=placement;children[i]=child;
        }
    }
    if(node.contains("children"))node["children"]=children;
    return node;
}

// 统一急刹卡片文案；文本框与上方图标共用竖直中心线，保留原字号和高度。
QJsonObject normalizeEmergencyLabel(QJsonObject node) {
    auto children=node.value("children").toArray();
    const bool emergency=node.value("stateBinding").toString()==QStringLiteral("ui.predictionEmergency");
    const double cardWidth=node.value("size").toObject().value("x").toDouble();
    double center=cardWidth/2;
    if(emergency)for(const auto &value:children) {
        const auto child=value.toObject();
        if(child.value("type")==QStringLiteral("TEXT"))continue;
        center=child.value("transform").toObject().value("m02").toDouble()+
            child.value("size").toObject().value("x").toDouble()/2;
        break;
    }
    QJsonArray updated;
    for(const auto &value:children) {
        auto child=normalizeEmergencyLabel(value.toObject());
        if(emergency&&child.value("type")==QStringLiteral("TEXT")) {
            child["text"]=QStringLiteral("急刹/避碰");
            child["align"]=QStringLiteral("CENTER");
            auto size=child.value("size").toObject();size["x"]=cardWidth;
            auto placement=child.value("transform").toObject();placement["m02"]=center-cardWidth/2;
            child["size"]=size;child["transform"]=placement;
        }
        updated.append(child);
    }
    if(node.contains("children"))node["children"]=updated;
    return node;
}

// 保留导出原稿，只在加载后收敛页面：删除旧四路视图页，把四路测距页改名四路视图。
void normalizeDesignPages(QJsonArray &pages) {
    const QStringList order{QStringLiteral("six"),QStringLiteral("four"),
        QStringLiteral("single"),QStringLiteral("space")};
    QJsonArray ordered;
    for(const QString &key:order) {
        for(const auto &value:pages) {
            auto page=value.toObject();
            if(page.value("key").toString()!=key)continue;
            QString name=page.value("name").toString();
            name.replace(QStringLiteral("4路测距"),QStringLiteral("4路视图"));
            page["name"]=name;
            qreal multiX=0,multiY=0;
            if(findActionPlacement(page,QStringLiteral("page:multi"),multiX,multiY))
                page=normalizeNavigation(page,multiX,multiY);
            if(key==QStringLiteral("four"))page=bindFourCameras(page);
            if(key==QStringLiteral("six")||key==QStringLiteral("four"))
                attachRangeSwitch(page,key);
            ordered.append(normalizeEmergencyLabel(page));
            break;
        }
    }
    for(const auto &value:pages) {
        auto page=value.toObject();
        const QString key=page.value("key").toString();
        if(order.contains(key)||key==QStringLiteral("multi"))continue;
        ordered.append(normalizeEmergencyLabel(page));
    }
    pages=ordered;
}
}

// HUD 叠加：为 true 时不绘制页面根节点的底色，让下层 GL 视频透出。
static bool gHudMode = false;

class DesignItem final : public QGraphicsObject {
public:
    QJsonObject data;
    QString text;
    QColor stateInk;
    QVariant stateLabel;
    QString action;   // 该节点对应的交互动作名（来自 design.json）
    bool hudPunch = false; // HUD 模式下该节点及其祖先只画描边，不画填充（让视频透出）
    bool switchOn = false;
    bool switchDisabled = false;
    QImage replacement;
    bool hasReplacement = false;
    // 静态图层分类：ownDynamic=自身外观可变；subtreeDynamic=自身或后代可变；
    // staticBaked=已合并进静态图层，场景不再单独绘制（直接 paint 仍可用）。
    bool ownDynamic = false;
    bool subtreeDynamic = false;
    bool staticBaked = false;
    bool bakeBlocker = false;
    // 处于 ui.prediction* / ui.change* 状态根之下：会按状态改描边色(stateInk)
    // 或文字(stateLabel)，即使自身没有绑定也不能烘焙。
    bool underStateInk = false;
    struct Geometry {QPainterPath path; QJsonArray paints;};
    QVector<Geometry> fills,strokes;
    QMap<QString,QImage> images;
    explicit DesignItem(const QJsonObject &node, const QString &assetsDir, QGraphicsItem *parent=nullptr)
        : QGraphicsObject(parent),data(node),text(node.value("text").toString()) {
        const auto t=node.value("transform").toObject();
        setTransform(QTransform(t.value("m00").toDouble(1),t.value("m10").toDouble(),
            t.value("m01").toDouble(),t.value("m11").toDouble(1),
            t.value("m02").toDouble(),t.value("m12").toDouble()));
        setVisible(node.value("visible").toBool(true));
        setOpacity(node.value("opacity").toDouble(1));
        setAcceptedMouseButtons(Qt::NoButton);
        if(node.value("draggable").toBool()) {
            setAcceptedMouseButtons(Qt::LeftButton);
            setFlag(ItemIsMovable);setFlag(ItemSendsGeometryChanges);
            setCursor(Qt::OpenHandCursor);
        }
        if(node.value("clip").toBool())setFlag(ItemClipsChildrenToShape);
        for(const auto &v:node.value("fillPaths").toArray()) {
            const auto g=v.toObject(); fills.append({makePath(g),g.value("paints").toArray()});
        }
        for(const auto &v:node.value("strokePaths").toArray()) {
            const auto g=v.toObject(); strokes.append({makePath(g),g.value("paints").toArray()});
        }
        for(const auto &v:node.value("fills").toArray()) {
            const auto p=v.toObject();const auto key=p.value("imageKey").toString();
            if(!key.isEmpty())images.insert(key,QImage(assetsDir+"/images/"+key));
        }
    }
    QVariant itemChange(GraphicsItemChange change,const QVariant &value) override {
        if(change==ItemPositionChange && data.value("draggable").toBool()
                && data.value("dragBounds")=="parent" && parentItem()) {
            const auto *parent=dynamic_cast<DesignItem*>(parentItem());
            if(parent) {
                const QRectF bounds=parent->layoutRect();
                const QRectF base=mapRectToParent(layoutRect()).translated(-pos());
                const QPointF proposed=value.toPointF();
                return QPointF(qBound(bounds.left()-base.left(),proposed.x(),qMax(bounds.left()-base.left(),bounds.right()-base.right())),
                    qBound(bounds.top()-base.top(),proposed.y(),qMax(bounds.top()-base.top(),bounds.bottom()-base.bottom())));
            }
        }
        return QGraphicsObject::itemChange(change,value);
    }
    void mousePressEvent(QGraphicsSceneMouseEvent *event) override {
        if(data.value("draggable").toBool())setCursor(Qt::ClosedHandCursor);
        QGraphicsObject::mousePressEvent(event);
    }
    void mouseReleaseEvent(QGraphicsSceneMouseEvent *event) override {
        QGraphicsObject::mouseReleaseEvent(event);
        if(data.value("draggable").toBool())setCursor(Qt::OpenHandCursor);
    }
    QRectF layoutRect() const {
        const auto s=data.value("size").toObject();
        return QRectF(0,0,s.value("x").toDouble(),s.value("y").toDouble());
    }
    QRectF boundingRect() const override {
        QRectF bounds=layoutRect();
        // Qt must know about the complete painted outline, including strokes
        // outside the layout box, to avoid cutting it during redraw/culling.
        for(const auto &g:fills)bounds=bounds.united(g.path.boundingRect());
        for(const auto &g:strokes)bounds=bounds.united(g.path.boundingRect());
        if(strokes.isEmpty() && !data.value("strokes").toArray().isEmpty()) {
            const double half=data.value("strokeWeight").toDouble()/2;
            bounds=bounds.adjusted(-half,-half,half,half);
        }
        return bounds.adjusted(-0.5,-0.5,0.5,0.5);
    }
    QPainterPath shape() const override {
        QPainterPath p; p.addRoundedRect(layoutRect(),data.value("radius").toDouble(),data.value("radius").toDouble());return p;
    }
    QRectF artworkRect() const {
        QRectF bounds;
        for(const auto &g:fills)bounds=bounds.united(g.path.boundingRect());
        for(const auto &g:strokes)bounds=bounds.united(g.path.boundingRect());
        return bounds;
    }
    QTransform artworkTransform() const {
        const QRectF rect=layoutRect(),artwork=artworkRect();
        const bool circle=data.value("name").toString().startsWith(QStringLiteral("圆形按键"));
        const bool smallVector=data.value("type")=="VECTOR"&&rect.width()<=64&&rect.height()<=64;
        QTransform t;
        if(!artwork.isEmpty()&&(circle||(smallVector&&!rect.contains(artwork)))) {
            const double inset=qMin(0.5,qMin(rect.width(),rect.height())/4);
            const QRectF target=circle?rect.adjusted(3,3,-3,-3):rect.adjusted(inset,inset,-inset,-inset);
            const double scale=qMin(target.width()/artwork.width(),target.height()/artwork.height());
            const QPointF offset=target.center()-QPointF(artwork.center().x()*scale,artwork.center().y()*scale);
            t.translate(offset.x(),offset.y());t.scale(scale,scale);
        }
        return t;
    }
    void paint(QPainter *p,const QStyleOptionGraphicsItem*,QWidget*) override {
        const auto rect=layoutRect();if(rect.isEmpty())return;
        if(p->hasClipping()&&!p->clipRegion().intersects(boundingRect().toAlignedRect()))return;
        if(gHudMode && !parentItem())return; // 页面根只有底色，HUD 模式下不画
        p->setRenderHint(QPainter::Antialiasing);p->setRenderHint(QPainter::SmoothPixmapTransform);
        if(data.value("type")=="TEXT") {
            const QString text=stateLabel.isValid()?stateLabel.toString():this->text;
            static const QString family=fontFamily();
            QFont font(family);font.setPixelSize(qMax(1,qRound(data.value("fontSize").toDouble(14))));
            const auto style=data.value("fontStyle").toString();
            font.setWeight(style.contains("Bold")?QFont::Bold:style.contains("Medium")?QFont::Medium:QFont::Normal);
            p->setFont(font);
            QColor ink("#d9e9ed");
            for(const auto &v:data.value("fills").toArray()) {
                const auto paint=v.toObject();if(paint.value("visible").toBool(true)) {ink=color(paint.value("color"),paint.value("opacity").toDouble(1));break;}
            }
            p->setPen(stateInk.isValid()?stateInk:ink);
            const auto align=data.value("align").toString();
            p->setClipRect(rect,Qt::IntersectClip);
            const QFontMetricsF metrics(font);
            if(!text.contains('\n')) {
                // Figma labels have fixed boxes. Keep a single line inside its box,
                // rather than letting fallback font metrics wrap it onto a neighbour.
                // Preserve glyph proportions. A long runtime label must not
                // squeeze the font horizontally to fit the exported box.
                const QRectF originalBounds=metrics.tightBoundingRect(text);
                const double fit=originalBounds.height()>rect.height()?
                    rect.height()/originalBounds.height():1.;
                const QString display=metrics.elidedText(text,Qt::ElideRight,rect.width()/fit);
                const QRectF inkBounds=metrics.tightBoundingRect(display);
                const double left=qMin(0.,inkBounds.left());
                const double width=qMax(metrics.horizontalAdvance(display),inkBounds.right())-left;
                const double scaleX=fit;
                const double scaleY=fit;
                // Font ascent/descent includes space not occupied by these glyphs.
                // Place actual glyph ink inside the box. In particular, never cap
                // a CJK baseline at height-descent: that lifts and cuts its top.
                const double padding=qMin(1.,qMax(0.,(rect.height()-inkBounds.height()*scaleY)/2));
                const double firstBaseline=padding-inkBounds.top()*scaleY;
                const double lastBaseline=rect.height()-padding-inkBounds.bottom()*scaleY;
                const double baseline=qBound(firstBaseline,
                    data.value("baseline").toDouble(firstBaseline),qMax(firstBaseline,lastBaseline));
                const double x=align=="CENTER"?(rect.width()-width*scaleX)/2:
                    align=="RIGHT"?rect.width()-width*scaleX:0.;
                p->save();p->translate(x-left*scaleX,baseline);p->scale(scaleX,scaleY);
                p->drawText(QPointF(0,0),display);
                p->restore();
            } else {
                int flags=Qt::AlignTop|Qt::TextWordWrap;
                flags|=align=="CENTER"?Qt::AlignHCenter:align=="RIGHT"?Qt::AlignRight:Qt::AlignLeft;
                p->drawText(rect,flags,text);
            }
            return;
        }
        if(data.value("type")==QStringLiteral("SWITCH")) {
            const auto paintColor=[&](const char *key,const char *fallback) {
                const QColor value(data.value(QString::fromLatin1(key)).toString());
                return value.isValid()?value:QColor(QString::fromLatin1(fallback));
            };
            QColor track=paintColor(switchOn?"onColor":"offColor",switchOn?"#103c39":"#0c1a22");
            QColor border=paintColor(switchOn?"onBorderColor":"offBorderColor",switchOn?"#29dfc8":"#27444f");
            QColor knob=paintColor(switchOn?"onKnobColor":"offKnobColor",switchOn?"#08141d":"#8ba5b1");
            if(switchDisabled) {
                track.setAlphaF(track.alphaF()*0.45);
                border.setAlphaF(border.alphaF()*0.45);
                knob.setAlphaF(knob.alphaF()*0.45);
            }
            const qreal radius=qMax(0.0,data.value("radius").toDouble(rect.height()/2));
            p->setPen(QPen(border,1.5));
            p->setBrush(track);
            p->drawRoundedRect(rect.adjusted(0.75,0.75,-0.75,-0.75),radius,radius);
            const qreal padding=2;
            const qreal knobSize=rect.height()-2*padding;
            const qreal knobX=switchOn?rect.width()-knobSize-padding:padding;
            p->setPen(Qt::NoPen);
            p->setBrush(knob);
            p->drawEllipse(QRectF(knobX,padding,knobSize,knobSize));
            return;
        }
        p->setTransform(artworkTransform(),true);
        auto drawPaints=[&](const QPainterPath &path,const QJsonArray &paints,bool outline=false,bool strokeGeometry=false) {
            for(const auto &v:paints) {
                auto paint=v.toObject();if(!paint.value("visible").toBool(true))continue;
                const bool stroke=outline||strokeGeometry;
                if(stateInk.isValid()&&paint.value("type")=="SOLID"&&
                    (data.value("type")=="VECTOR"||
                     (data.value("type")=="ROUNDED_RECTANGLE"&&color(paint.value("color")).valueF()>0.3)||
                     (data.value("type")=="ELLIPSE"&&stroke)))
                    paint["color"]=stateInk.name(QColor::HexRgb);
                if(paint.value("type")=="IMAGE") {
                    const QImage &image=hasReplacement?replacement:images[paint.value("imageKey").toString()];
                    if(image.isNull())continue;
                    const double factor=qMax(rect.width()/image.width(),rect.height()/image.height());
                    const QSizeF size(image.width()*factor,image.height()*factor);
                    const QRectF target(rect.center()-QPointF(size.width()/2,size.height()/2),size);
                    p->save();p->setClipPath(path);p->setOpacity(p->opacity()*paint.value("opacity").toDouble(1));
                    p->drawImage(target,image);p->restore();
                } else if(outline) {
                    QPen pen(paintBrush(paint,rect),data.value("strokeWeight").toDouble(1));
                    pen.setJoinStyle(Qt::RoundJoin);p->setBrush(Qt::NoBrush);p->setPen(pen);p->drawPath(path);
                } else {p->fillPath(path,paintBrush(paint,rect));}
            }
        };
        QPainterPath fallback;
        if(data.value("type")=="ELLIPSE")fallback.addEllipse(rect);
        else fallback.addRoundedRect(rect,data.value("radius").toDouble(),data.value("radius").toDouble());
        if(fills.isEmpty()){if(!(gHudMode&&hudPunch))drawPaints(fallback,data.value("fills").toArray());}
        else for(const auto &g:fills)if(!(gHudMode&&hudPunch))drawPaints(g.path,g.paints.isEmpty()?data.value("fills").toArray():g.paints);
        if(strokes.isEmpty())drawPaints(fallback,data.value("strokes").toArray(),true);
        // Exported stroke geometry is already a filled outline, not a centerline.
        else for(const auto &g:strokes)drawPaints(g.path,g.paints.isEmpty()?data.value("strokes").toArray():g.paints,false,true);
    }
};

DesignView::DesignView(QWidget *parent,const QString &assetsDir,const QString &mode):QGraphicsView(parent) {
    setScene(new QGraphicsScene(this));setBackgroundBrush(QColor("#080f14"));
    setFrameShape(QFrame::NoFrame);setRenderHints(QPainter::Antialiasing|QPainter::SmoothPixmapTransform);
    setHorizontalScrollBarPolicy(Qt::ScrollBarAlwaysOff);setVerticalScrollBarPolicy(Qt::ScrollBarAlwaysOff);
    QString root=assetsDir.isEmpty()?designRoot():QDir(assetsDir).absolutePath();
    auto readObject=[](const QString &file){QFile f(file);return f.open(QIODevice::ReadOnly)?QJsonDocument::fromJson(f.readAll()).object():QJsonObject();};
    auto manifest=readObject(root+"/manifest.json");
    if(!manifest.isEmpty())root=QDir(root).filePath(manifest.value("current").toString("assets"));
    else manifest=readObject(root+"/../manifest.json");
    assetsDir_=root;
    const QString selected=mode.isEmpty()?manifest.value("mode").toString("token"):mode;
    if(selected!="token"&&selected!="resolved")return;
    const auto design=readObject(root+(selected=="resolved"?"/design.resolved.json":"/design.json"));
    pages_=resolveTokens(design.value("pages"),readObject(root+"/tokens.json")).toArray();
    // 资源缺失时明确报出来，避免界面静默空屏。
    if(pages_.isEmpty())fprintf(stderr,"[designview] design.json not found (root=%s)\n",qPrintable(root));
    normalizeDesignPages(pages_);
    // 页面集合已在运行时收敛，默认仍打开六路视图。
    int initial=-1;
    for(int i=0;i<pages_.size();++i)
        if(pages_[i].toObject().value("key").toString()==QStringLiteral("six")){initial=i;break;}
    if(!pages_.isEmpty())setPage(initial>=0?initial:0);
}
QStringList DesignView::pageNames() const {QStringList r;for(const auto &p:pages_)r<<p.toObject().value("name").toString();return r;}
QStringList DesignView::pageIds() const {QStringList r;for(const auto &p:pages_)r<<p.toObject().value("id").toString();return r;}
QString DesignView::currentPageKey() const {
    if(pageIndex_<0||pageIndex_>=pages_.size())return {};
    return pages_[pageIndex_].toObject().value("key").toString();
}
DesignItem *DesignView::addNode(const QJsonObject &node,DesignItem *parent) {
    auto *item=new DesignItem(node,assetsDir_,parent);
    // The single video host paints a movable replacement for this fixed card.
    if(currentPageKey()==QStringLiteral("single") && node.value("id").toString()==QStringLiteral("3:7497"))
        item->setVisible(false);
    if(!parent)scene()->addItem(item);
    const auto id=node.value("id").toString();items_.insert(id,item);
    if(textOverrides_.contains(id))item->text=textOverrides_.value(id);
    if(imageOverrides_.contains(id)){item->replacement=imageOverrides_.value(id);item->hasReplacement=true;}
    // Constant normalizations belong to page compilation, not per-frame perception.
    const auto name=node.value("name").toString();
    if(name==QStringLiteral("预测结果")&&!textOverrides_.contains(id))item->text=QStringLiteral("--");
    if(name==QStringLiteral("面板状态")&&node.value("text").toString().contains(QStringLiteral("厘米")))
        item->text=QStringLiteral("最近目标 · 米");
    if(name==QStringLiteral("按键说明")&&node.value("text")==QStringLiteral("当前选中"))
        item->text=QStringLiteral("车道选择");
    if(name==QStringLiteral("目标检测框"))item->setVisible(false);
    // 状态着色根的判定必须先于子节点：后代要继承这个标记（stateInk/stateLabel）。
    const QString stateKey=node.value("interaction").toObject().value("stateBinding")
        .toString(node.value("stateBinding").toString());
    // Alpha on a parent is applied to each original primitive. Flattening its
    // overlapping children first changes compositing, so stateful/transparent
    // ancestry must remain dynamic as well as the ink-inheriting cards.
    const bool inkRoot=!stateKey.isEmpty()||!node.value("interaction").toObject().isEmpty()||
        node.value("opacity").toDouble(1)<1.0;
    item->underStateInk=inkRoot||(parent&&parent->underStateInk);
    item->ownDynamic=nodeOwnDynamic(node)||item->underStateInk;
    item->bakeBlocker=(!staticLayerBakesVectors()&&node.value("type")==QStringLiteral("VECTOR"))||
        !axisAlignedTransform(node);
    int z=0;
    for(const auto &v:node.value("children").toArray())addNode(v.toObject(),item)->setZValue(z++);
    if(node.value("iconAlignment")=="center-path-bounds") {
        QRectF ink;
        QVector<DesignItem*> icons;
        const auto ids=node.value("iconSubtreeIds").toArray();
        for(auto *child:item->childItems())if(auto *d=dynamic_cast<DesignItem*>(child);d&&ids.contains(d->data.value("id")))icons.append(d);
        std::function<void(DesignItem*)> measure=[&](DesignItem *child){
            if(!child->isVisible())return;
            if(child->data.value("type")=="VECTOR")ink=ink.united(child->mapRectToItem(item,child->artworkTransform().mapRect(child->artworkRect())));
            for(auto *c:child->childItems())if(auto *d=dynamic_cast<DesignItem*>(c))measure(d);
        };
        for(auto *child:icons)measure(child);
        if(!ink.isEmpty()) {
            const QPointF offset=item->layoutRect().center()-ink.center();
            for(auto *child:icons)child->setPos(child->pos()+offset);
        }
    }
    // 视频槽及其祖先在 HUD 模式下不画填充，让下层 GL 画面透出。
    if(node.value("binding").toString()==QStringLiteral("frame")) {
        for(DesignItem *p=item;p;p=dynamic_cast<DesignItem*>(p->parentItem()))p->hudPunch=true;
        frameItems_.append(item);
    }
    const auto action=node.value("action").toString();
    if(!action.isEmpty()) {
        // eglfs 下 QGraphicsProxyWidget 会触发第二次平台窗口创建并崩溃，
        // 因此按钮改为纯场景命中：记录动作名，由视图在点击时判定。
        item->action=action;
        item->setCursor(Qt::PointingHandCursor);
    }
    // 静态图层分类：整棵子树都没有运行期可变的图元，才能整体烘焙。
    // 祖先 opacity 变化由场景绘制整棵子树处理，无需展开。
    item->subtreeDynamic=item->ownDynamic||item->bakeBlocker;
    for(auto *child:item->childItems())
        if(auto *design=dynamic_cast<DesignItem*>(child))
            item->subtreeDynamic=item->subtreeDynamic||design->subtreeDynamic;
    if(item->ownDynamic)dynamicItems_.append(item);
    return item;
}
void DesignView::setPage(int index) {
    if(index<0||index>=pages_.size())return;
    // 场景清空会连带析构静态图层图元，这里只清索引，不能 delete。
    scene()->clear();
    items_.clear();
    dynamicItems_.clear();
    frameItems_.clear();
    slotTextItems_.clear();
    staticLayerItems_.clear();
    staticBakedNodes_=0;
    staticLayerBytes_=0;
    staticLayerBuildMs_=0;
    staticLayerScale_=0;
    staticLayersValid_=false;
    bakedOverrideVersion_=-1;
    retiredStaticNodes_=0;nodeRects_.clear();nodeArtwork_.clear();
    pageIndex_=index;++revision_;
    auto page=pages_[index].toObject();
    // 板端 16:9 显示收紧底部空白，保留所有文字、操作及状态栏。
    if(hud_) {
        constexpr double displayHeight=1064;
        auto size=page.value("size").toObject();size["y"]=displayHeight;page["size"]=size;
        auto children=page.value("children").toArray();
        for(int i=0;i<children.size();++i) {
            auto child=children[i].toObject();
            auto transform=child.value("transform").toObject();
            auto childSize=child.value("size").toObject();
            const double top=transform.value("m12").toDouble();
            const double height=childSize.value("y").toDouble();
            if(top>1064 && height<=32) {
                transform["m12"]=1030;child["transform"]=transform;
            } else if(top<displayHeight && top+height>displayHeight) {
                childSize["y"]=displayHeight-top;child["size"]=childSize;
            }
            children[i]=child;
        }
        page["children"]=children;
    }
    auto *root=addNode(page,nullptr);scene()->setSceneRect(root->layoutRect());
    collectLegacyCountBindings();
    if(hasState_)applyPerception(lastState_);
    refreshBindingVisuals();
    collectSlotTextItems();
    captureArtwork();
    fitPage();
    emit pageChanged(index);
}
void DesignView::showPage(const QString &key) {
    for(int i=0;i<pages_.size();++i)if(pages_[i].toObject().value("key").toString()==key){setPage(i);return;}
}
void DesignView::setHudMode(bool on) {
    if(hud_!=on&&retiredStaticNodes_>0) {
        hud_=on;gHudMode=on;rebuildPagePreservingBindings();
    }
    hud_=on;gHudMode=on;++revision_;
    // HUD 开关会改变页面根底色与 video 槽的挖空绘制，静态图层必须重新生成。
    invalidateStaticLayers();
    // 视图自身不铺底色，viewport 也不填充，交给下层 GL 视频透出。
    setBackgroundBrush(on?QBrush(Qt::NoBrush):QBrush(QColor("#080f14")));
    viewport()->setAutoFillBackground(!on);
    viewport()->setAttribute(Qt::WA_TranslucentBackground,on);
    viewport()->setAttribute(Qt::WA_NoSystemBackground,on);
    setAttribute(Qt::WA_TranslucentBackground,on);
    setStyleSheet(on?QStringLiteral("QGraphicsView{background:transparent;}"):QString());
    setViewportUpdateMode(QGraphicsView::FullViewportUpdate);
    if(!on)fitPage();
    ensureStaticLayers();
    if(scene())scene()->update();
}
void DesignView::setNodeText(const QString &id,const QString &text) {
    if(retiredStaticNodes_>0&&!items_.contains(id)) {
        textOverrides_.insert(id,text);rebuildPagePreservingBindings();return;
    }
    textOverrides_.insert(id,text);if(auto *item=items_.value(id,nullptr)){
        if(item->text!=text){item->text=text;++revision_;}
        // 已经烘焙的静态文字不会随 update 重画，必须重建静态图层。
        if(item->staticBaked){++overrideVersion_;ensureStaticLayers();}
        item->update();}
}
void DesignView::setNodeImage(const QString &id,const QImage &image) {
    if(retiredStaticNodes_>0&&!items_.contains(id)) {
        imageOverrides_.insert(id,image);rebuildPagePreservingBindings();return;
    }
    imageOverrides_.insert(id,image);if(auto *item=items_.value(id,nullptr)){
        item->replacement=image;item->hasReplacement=true;
        if(item->staticBaked){++overrideVersion_;ensureStaticLayers();}
        item->update();}
}
QVector<QRectF> DesignView::frameRectsInScene() const {
    QVector<QRectF> out;
    for(auto *item : frameItems_)
        out.append(item->mapRectToScene(item->layoutRect()));
    return out;
}
QMap<int, QRectF> DesignView::channelRectsInScene() const {    QMap<int, QRectF> out;
    for(auto *item:frameItems_)
        if(item->isVisible())
            out.insert(item->data.value("channelIndex").toInt(-1),item->mapRectToScene(item->layoutRect()));
    return out;
}
void DesignView::collectSlotTextItems() {
    slotTextItems_.clear();
    const auto slotRects=frameRectsInScene();
    if(slotRects.isEmpty())return;
    // 保持与旧实现一致的遍历顺序（items_ 按节点 id 排序），避免补画顺序变化。
    for(auto *item:items_) {
        if(item->data.value("type").toString()!=QStringLiteral("TEXT"))continue;
        const QPointF center=item->mapToScene(item->layoutRect().center());
        for(const QRectF &slot:slotRects)
            if(slot.contains(center)){
                slotTextItems_.append(item);
                // These are painted after the GL video holes are cleared.
                for(auto *p=item;p;p=dynamic_cast<DesignItem*>(p->parentItem()))p->subtreeDynamic=true;
                break;
            }
    }
}
void DesignView::collectLegacyCountBindings() {
    legacyCountBindings_.clear();
    const QMap<QString,QString> categories{
        {"机动车","机动车"},{"车辆","机动车"},{"行人","行人"},{"自行车","自行车"},
        {"非机动车","自行车"},{"公交车","公交车"},{"摩头车","摩托车"},{"摩托车","摩托车"},
        {"车道线","__none__"},{"障碍物","__none__"}};
    const QRegularExpression countPattern(QStringLiteral("^\\d{1,3}$"));
    QVector<DesignItem*> labels,counts;
    for(auto *item:items_) {
        if(item->data.value("name")==QStringLiteral("目标数量")) {
            if(auto *parent=item->parentItem())for(auto *child:parent->childItems()) {
                auto *label=dynamic_cast<DesignItem*>(child);
                if(label&&label->data.value("name")==QStringLiteral("目标类别"))
                    legacyCountBindings_[item->data.value("id").toString()]=label->data.value("text").toString();
            }
        }
        if(item->data.value("type")!=QStringLiteral("TEXT"))continue;
        const auto text=item->data.value("text").toString();
        if(categories.contains(text))labels.append(item);
        else if(countPattern.match(text).hasMatch())counts.append(item);
    }
    for(auto *label:labels) {
        const auto lc=label->mapToScene(label->layoutRect().center());
        DesignItem *nearest=nullptr;qreal gap=1e9;
        for(auto *count:counts) {
            const auto c=count->mapToScene(count->layoutRect().center());
            if(c.x()>lc.x()&&qAbs(c.y()-lc.y())<=20&&c.x()-lc.x()<gap){gap=c.x()-lc.x();nearest=count;}
        }
        if(nearest)legacyCountBindings_[nearest->data.value("id").toString()]=categories.value(label->data.value("text").toString());
    }
}
QGraphicsItem *DesignView::nodeById(const QString &figmaId) const {
    return items_.value(figmaId,nullptr);
}
QRectF DesignView::nodeSceneRect(const QString &id) const {
    if(auto *item=items_.value(id,nullptr))return item->sceneBoundingRect();
    return nodeRects_.value(id);
}
QImage DesignView::nodeArtwork(const QString &id) const { return nodeArtwork_.value(id); }
void DesignView::captureArtwork() {
    for(auto it=items_.cbegin();it!=items_.cend();++it)nodeRects_[it.key()]=it.value()->sceneBoundingRect();
    for(const QString &id:{QStringLiteral("192:493"),QStringLiteral("192:502"),QStringLiteral("192:514")}) {
        auto *root=items_.value(id,nullptr);if(!root)continue;
        const auto bounds=root->boundingRect().united(root->childrenBoundingRect());
        if(bounds.isEmpty())continue;
        QImage image(72,72,QImage::Format_ARGB32_Premultiplied);image.fill(Qt::transparent);
        QPainter painter(&image);painter.setRenderHint(QPainter::Antialiasing);
        painter.translate(36,36);const double factor=64/qMax(bounds.width(),bounds.height());
        painter.scale(factor,factor);painter.translate(-bounds.center());
        std::function<void(QGraphicsItem*)> draw=[&](QGraphicsItem *item){
            if(!item->isVisible())return;
            painter.save();if(item!=root)painter.setTransform(item->itemTransform(item->parentItem()),true);
            item->paint(&painter,nullptr,nullptr);
            for(auto *child:item->childItems())draw(child);
            painter.restore();
        };
        draw(root);painter.end();nodeArtwork_[id]=image;
    }
}
void DesignView::retireStaticNodes() {
    const QString auditDir=qEnvironmentVariable("ADS_STATIC_AUDIT_DIR");
    if(!auditDir.isEmpty()) {
        QJsonArray nodes;
        for(auto *item:items_) {
            const QString binding=item->data.value("binding").toString();
            const QString kind=item->staticBaked?"background-image":item->ownDynamic?"dynamic":
                slotTextItems_.contains(item)?"video-slot-text":"layout-or-vector";
            const auto rect=item->sceneBoundingRect();
            nodes.append(QJsonObject{{"id",item->data.value("id")},{"name",item->data.value("name")},
                {"text",item->data.value("text")},{"binding",binding},{"kind",kind},
                {"type",item->data.value("type")},{"rect",QJsonArray{rect.x(),rect.y(),rect.width(),rect.height()}},
                {"stateInherited",item->underStateInk},{"action",item->action}});
        }
        QDir().mkpath(auditDir);QFile file(auditDir+"/"+currentPageKey()+".json");
        if(file.open(QIODevice::WriteOnly))file.write(QJsonDocument(nodes).toJson(QJsonDocument::Indented));
    }
    QVector<DesignItem*> roots;
    for(auto *item:items_)if(item->staticBaked) {
        auto *parent=dynamic_cast<DesignItem*>(item->parentItem());
        if(!parent||!parent->staticBaked)roots.append(item);
    }
    for(auto it=items_.begin();it!=items_.end();) {
        if(it.value()->staticBaked){++retiredStaticNodes_;it=items_.erase(it);}else ++it;
    }
    for(auto *root:roots)delete root;
}
void DesignView::paintSlotText(QPainter *painter,const QRectF &source,const QRectF &target) const {
    if(!painter || source.isEmpty() || target.isEmpty())return;
    // 槽内文本在加载时已索引，正常帧不再遍历场景、也不重复做包含判定。
    if(slotTextItems_.isEmpty())return;
    painter->save();
    QTransform base;
    // fit 模式内容不铺满视口，必须补上居中留边的设备像素偏移，否则槽内文字整体偏移
    base.translate(target.left(),target.top());
    base.scale(target.width()/source.width(),target.height()/source.height());
    base.translate(-source.left(),-source.top());
    painter->setWorldTransform(base,true);
    for(auto *item:slotTextItems_) {
        if(!item->isVisible())continue;
        painter->save();
        painter->setWorldTransform(item->sceneTransform(),true);
        item->paint(painter,nullptr,nullptr);
        painter->restore();
    }
    painter->restore();
}
QString DesignView::actionAtScene(const QPointF &point) const {    if(!scene())return {};
    for(QGraphicsItem *hit:scene()->items(point))
        for(QGraphicsItem *p=hit;p;p=p->parentItem())
            if(auto *d=dynamic_cast<DesignItem*>(p);d && !d->action.isEmpty()) {
                const QString key=d->data.value("interaction").toObject().value("stateBinding").toString(d->data.value("stateBinding").toString());
                if(bindingValues_.value(key).toString()=="disabled")return {};
                return d->action;
            }
    return {};
}
void DesignView::applyPerception(const PerceptionState &state) {
    six_profile::Scope perceptionProfile("apply_perception");
    // 只读快照用于统计本轮真正改变了哪些绑定，不参与视觉判定。
    const auto bindingsBefore=six_profile::enabled()?bindingValues_:QMap<QString,QVariant>();
    beginVisualUpdate();
    lastState_=state;hasState_=true;
    for(auto *item:dynamicItems_) {
        const auto interaction=item->data.value("interaction").toObject();
        if(interaction.value("mode")=="output")bindingValues_[interaction.value("stateBinding").toString()]="normal";
    }
    for(auto it=state.visualStates.cbegin();it!=state.visualStates.cend();++it)bindingValues_[it.key()]=it.value();
    for(int i=0;i<6;++i) {
        const ChannelState channel=i<state.channels.size()?state.channels[i]:ChannelState();
        bindingValues_["channel.distanceValue:"+QString::number(i)]=channel.connected?channel.distanceMeters:-1;
        bindingValues_["channel.distanceSegments:"+QString::number(i)]=channel.connected?qMax(0,channel.distanceSegments):0;
        bindingValues_["channel.distanceUnit:"+QString::number(i)]=QStringLiteral("米");
    }
    // Bind by semantic names from the Figma file; direct node APIs handle custom fields.
    for(auto *item:dynamicItems_) {
        const auto name=item->data.value("name").toString();
        const auto binding=item->data.value("binding").toString();
        const int index=item->data.value("channelIndex").toInt(-1);
        const ChannelState *channel=index>=0 && index<state.channels.size()?&state.channels[index]:nullptr;
        const bool online=channel && channel->connected;
        const bool distanceValid=online && std::isfinite(channel->distanceMeters) && channel->distanceMeters>=0;
        // The exported boxes are design examples; live boxes belong to the backend.
        if(name==QStringLiteral("目标检测框"))item->setVisible(false);
        if(name==QStringLiteral("预测结果")&&!textOverrides_.contains(item->data.value("id").toString()))item->text=QStringLiteral("--");
        if(name==QStringLiteral("融合目标数")) {
            int total=0;for(int count:state.objectCounts)total+=count;
            item->text=state.objectCounts.isEmpty()?QStringLiteral("融合目标 -- 个"):
                QStringLiteral("融合目标 %1 个").arg(total);
        }
        if(name==QStringLiteral("面板状态") && item->data.value("text").toString().contains(QStringLiteral("厘米")))
            item->text=QStringLiteral("最近目标 · 米");
        if(name==QStringLiteral("按键说明") && item->data.value("text")==QStringLiteral("当前选中"))
            item->text=QStringLiteral("车道选择");
        if(binding=="frame") {
            item->hasReplacement=true;
            item->replacement=online?channel->frame:QImage();
        } else if(binding=="channelName")item->text=channel?channel->name:QStringLiteral("未连接");
        else if(binding=="targetLabel")item->text=online?channel->targetLabel:QStringLiteral("--");
        else if(binding=="distance" || binding=="distanceValue")item->text=distanceValid?
            QString::number(channel->distanceMeters,'f',1)+(binding=="distance"?QStringLiteral(" m"):QString()):QStringLiteral("--");
        else if(binding=="distanceUnit")item->text=QStringLiteral("米");
        else if(binding=="fps")item->text=online?QStringLiteral("%1 FPS").arg(channel->fps,0,'f',1):QStringLiteral("离线");
        else if(binding=="connected")item->text=online?QStringLiteral("已连接"):QStringLiteral("离线");
        else if(binding=="trafficLight")item->text=state.trafficLight.isEmpty()?QStringLiteral("未知"):state.trafficLight;
        else if(binding=="nextAction")item->text=state.nextAction.isEmpty()?QStringLiteral("等待预测"):state.nextAction;
        else if(binding=="trafficAction")item->text=QStringLiteral("信号灯：%1 ｜ %2").arg(
            state.trafficLight.isEmpty()?QStringLiteral("未知"):state.trafficLight,
            state.nextAction.isEmpty()?QStringLiteral("等待预测"):state.nextAction);
        else if(binding=="drivingStatus")item->text=state.drivingStatus +
            (state.speedKph>=0?QStringLiteral(" · %1 km/h").arg(state.speedKph,0,'f',1):QString());
    }

    // 设计稿里不少数值只是普通文本（名字统一叫“标签”）。这里按占位文本识别语义，
    // 用真实数据替换；取不到真实值的显示“--”，不把设计样例当成实时数据。
    const auto slotRects=channelRectsInScene();
    auto channelNear=[&](const QPointF &point)->const ChannelState* {
        int best=-1;qreal bestDistance=1e9;
        for(auto it=slotRects.cbegin();it!=slotRects.cend();++it) {
            const QRectF &r=it.value();
            const QPointF gap(qMax(qMax(r.left()-point.x(),point.x()-r.right()),0.0),
                              qMax(qMax(r.top()-point.y(),point.y()-r.bottom()),0.0));
            const qreal distance=std::hypot(gap.x(),gap.y());
            if(distance<bestDistance){bestDistance=distance;best=it.key();}
        }
        if(best<0 || best>=state.channels.size() || bestDistance>400.)return nullptr;
        return &state.channels[best];
    };
    // 页面上出现过的类别名 -> 统计口径；没有对应统计的类别（车道线/障碍物）显示“--”
    static const QMap<QString,QString> categoryKeys={
        {QStringLiteral("机动车"),QStringLiteral("机动车")},{QStringLiteral("车辆"),QStringLiteral("机动车")},
        {QStringLiteral("行人"),QStringLiteral("行人")},{QStringLiteral("自行车"),QStringLiteral("自行车")},
        {QStringLiteral("非机动车"),QStringLiteral("自行车")},{QStringLiteral("公交车"),QStringLiteral("公交车")},
        {QStringLiteral("摩头车"),QStringLiteral("摩托车")},{QStringLiteral("摩托车"),QStringLiteral("摩托车")},
        // 没有实时统计来源的类别也登记进来，让计数显示“--”而不是设计样例
        {QStringLiteral("车道线"),QStringLiteral("__none__")},
        {QStringLiteral("障碍物"),QStringLiteral("__none__")}};
    const QRegularExpression fusedPattern(QStringLiteral("^融合目标\\s*\\d+\\s*个$"));
    const QRegularExpression metersPattern(QStringLiteral("^\\d+(?:\\.\\d+)?\\s*米$"));
    const QRegularExpression videoPattern(QStringLiteral("^\\d+\\s*×\\s*\\d+.*帧"));
    const QRegularExpression labelPattern(QStringLiteral("^\\S+\\s*\\d+\\s*·\\s*\\d+%$"));
    const QRegularExpression countPattern(QStringLiteral("^\\d{1,3}$"));
    for(auto it=legacyCountBindings_.cbegin();it!=legacyCountBindings_.cend();++it)
        if(auto *item=items_.value(it.key(),nullptr))item->text=state.objectCounts.contains(it.value())?
            QString::number(state.objectCounts.value(it.value())):QStringLiteral("--");
    for(auto *item:dynamicItems_) {
        if(item->data.value("type").toString()!=QStringLiteral("TEXT"))continue;
        if(!item->data.value("binding").toString().isEmpty())continue;
        const QString original=item->data.value("text").toString();
        if(original.isEmpty()||categoryKeys.contains(original)||countPattern.match(original).hasMatch())continue;
        const ChannelState *channel=channelNear(item->mapToScene(item->layoutRect().center()));
        const bool online=channel && channel->connected;
        const bool distanceValid=online && std::isfinite(channel->distanceMeters) && channel->distanceMeters>=0;
        QString replacement;
        if(fusedPattern.match(original).hasMatch()) {
            int total=0;bool known=false;
            for(auto it=state.objectCounts.cbegin();it!=state.objectCounts.cend();++it){total+=it.value();known=true;}
            replacement=known?QStringLiteral("融合目标 %1 个").arg(total):QStringLiteral("融合目标 -- 个");
        } else if(metersPattern.match(original).hasMatch()) {
            replacement=distanceValid?QStringLiteral("%1 米").arg(channel->distanceMeters,0,'f',1)
                                     :QStringLiteral("-- 米");
        } else if(videoPattern.match(original).hasMatch()) {
            replacement=online?QStringLiteral("%1 帧/秒").arg(channel->fps,0,'f',0):QStringLiteral("-- 帧/秒");
        } else if(labelPattern.match(original).hasMatch() || original.contains(QLatin1Char('%'))) {
            replacement=online&&!channel->targetLabel.isEmpty()?channel->targetLabel:QStringLiteral("--");
        } else if(original==QStringLiteral("已同步")||original==QStringLiteral("已连接")) {
            replacement=online?QStringLiteral("已同步"):QStringLiteral("离线");
        } else if(original==QStringLiteral("绿灯")||original==QStringLiteral("红灯")||original==QStringLiteral("黄灯")) {
            replacement=state.trafficLight.isEmpty()?QStringLiteral("未识别"):state.trafficLight;
        } else if(original==QStringLiteral("直行允许")||original==QStringLiteral("直行允许 ")) {
            replacement=state.nextAction.isEmpty()?QStringLiteral("待判定"):state.nextAction;
        } else continue;
        if(item->text!=replacement){item->text=replacement;}
    }
    refreshBindingVisuals();
    endVisualUpdate();
    six_profile::bindingChanges("perception.key.",bindingsBefore,bindingValues_);
}
void DesignView::mouseReleaseEvent(QMouseEvent *event) {
    QGraphicsView::mouseReleaseEvent(event);
    if(event->button()!=Qt::LeftButton||!scene())return;
    // 向上回溯父节点，命中最近一个带 action 的设计节点。
    const QString action=actionAtScene(mapToScene(event->pos()));
    const QString pressed=pressedAction_;pressedAction_.clear();
    if(!action.isEmpty()&&action==pressed) {
        QJsonObject selected;
        for(auto *item:items_)if(item->action==action)selected=item->data.value("interaction").toObject();
        if(selected.value("mode")=="latched") {
            for(auto *item:items_) {
                const auto interaction=item->data.value("interaction").toObject();
                if(interaction.value("mode")=="latched"&&interaction.value("group")==selected.value("group"))
                    bindingValues_[interaction.value("stateBinding").toString()]=interaction.value("stateBinding")==selected.value("stateBinding")?"active":"normal";
            }
        }
    }
    refreshBindingVisuals();
    if(!action.isEmpty()&&action==pressed)emit actionTriggered(action);
}
void DesignView::mousePressEvent(QMouseEvent *event) {
    if(event->button()==Qt::LeftButton){pressedAction_=actionAtScene(mapToScene(event->pos()));refreshBindingVisuals();}
    QGraphicsView::mousePressEvent(event);
}
void DesignView::setBindingValue(const QString &binding,const QVariant &value,int channelIndex) {
    bindingValues_[channelIndex<0?binding:binding+":"+QString::number(channelIndex)]=value;
    refreshBindingVisuals();}
void DesignView::setBindings(const QMap<QString,QVariant> &values) {
    six_profile::Scope bindingsProfile("set_bindings");
    bool changed=false;
    for(auto it=values.cbegin();it!=values.cend();++it) {
        if(!bindingValues_.contains(it.key())||bindingValues_.value(it.key())!=it.value()) {
            six_profile::keyed("binding.key.",it.key());
            bindingValues_[it.key()]=it.value();changed=true;
        }
    }
    if(changed||!property("cacheStableBindings").toBool())refreshBindingVisuals();
}
void DesignView::setStatCounts(const QVector<int> &counts) {
    QMap<QString,QVariant> values;
    for(int i=0;i<5;++i)values["stats.count:"+QString::number(i)]=i<counts.size()&&counts[i]>=0?QString::number(counts[i]):QStringLiteral("--");
    setBindings(values);
}
void DesignView::setPressedAction(const QString &action) {
    if(pressedAction_==action)return;
    pressedAction_=action;
    refreshBindingVisuals();
}
void DesignView::refreshBindingVisuals() {
    if(visualUpdateDepth_>0){bindingRefreshPending_=true;return;}
    beginVisualUpdate();
    applyBindingVisuals();
    endVisualUpdate();
}
void DesignView::applyBindingVisuals() {
    six_profile::count("binding.refresh_pass");
    for(auto *item:dynamicItems_) {
        const auto data=item->data;
        if(data.value("type").toString()==QStringLiteral("SWITCH")) {
            const QString state=bindingValues_.value(QStringLiteral("range.state")).toString();
            const bool on=state==QStringLiteral("on");
            const bool disabled=state==QStringLiteral("disabled");
            if(item->switchOn!=on||item->switchDisabled!=disabled) {
                item->switchOn=on;item->switchDisabled=disabled;
            }
        }
        const auto interaction=data.value("interaction").toObject();
        const QString mode=interaction.value("mode").toString();
        DesignItem *stateRoot=nullptr;
        QString effectiveBinding;
        for(auto *ancestor=static_cast<QGraphicsItem*>(item);ancestor;ancestor=ancestor->parentItem()) {
            auto *design=dynamic_cast<DesignItem*>(ancestor);
            if(!design)continue;
            const auto node=design->data;
            const QString key=node.value("interaction").toObject().value("stateBinding").toString(node.value("stateBinding").toString());
            if(key.isEmpty())continue;
            if(key.startsWith("ui.prediction")||key=="ui.changeLeft"||key=="ui.changeRight") {
                stateRoot=design;
                effectiveBinding=key;
            }
            break;
        }
        const QString inkValue=bindingValues_.value(effectiveBinding+".ink").toString();
        static const QRegularExpression inkPattern(QStringLiteral("^#[0-9a-fA-F]{6}$"));
        const QColor ink=stateRoot&&inkPattern.match(inkValue).hasMatch()?QColor(inkValue):QColor();
        item->stateInk=stateRoot&&stateRoot!=item?ink:QColor();
        item->stateLabel=QVariant();
        if(stateRoot&&stateRoot!=item&&data.value("type")=="TEXT"&&bindingValues_.contains(effectiveBinding+".label"))
            item->stateLabel=bindingValues_.value(effectiveBinding+".label");
        item->setData(NodeIdRole,data.value("id").toString());
        item->setData(StateBindingRole,effectiveBinding);
        item->setData(StateInkRole,ink.isValid()?ink.name(QColor::HexRgb):QString());
        if(!mode.isEmpty()) {
            const QString stateKey=interaction.value("stateBinding").toString(data.value("stateBinding").toString());
            const QString state=bindingValues_.value(stateKey,interaction.value("defaultState").toString("normal")).toString();
            const bool pressed=!item->action.isEmpty()&&item->action==pressedAction_;
            const double opacity=data.value("variants").toObject().value(state).toObject().value("opacity").toDouble(1);
            item->setOpacity(data.value("opacity").toDouble(1)*(state=="disabled"?opacity:pressed?0.65:opacity));
        }
        if(stateRoot==item) {
            const bool disabled=bindingValues_.value(effectiveBinding).toString()=="disabled";
            if(ink.isValid()&&!disabled)item->setOpacity(!item->action.isEmpty()&&item->action==pressedAction_?0.65:1);
            else if(mode.isEmpty())item->setOpacity(data.value("opacity").toDouble(1));
        }
        const QString binding=data.value("binding").toString();
        if(binding.isEmpty()) {
            item->setData(DisplayTextRole,data.value("type")=="TEXT"?
                (item->stateLabel.isValid()?item->stateLabel.toString():item->text):QString());
            continue;
        }
        if(binding=="vehicle.selectedHint"&&!bindingValues_.contains(binding)) {
            item->text=bindingValues_.value("ui.straight").toString()=="active"?QStringLiteral("当前选中"):QString();
        }
        const int index=data.value("channelIndex").toInt(data.value("bindingIndex").toInt(-1));
        const QString key=index<0?binding:binding+":"+QString::number(index);
        if(binding=="channel.distanceSegments") {
            const int count=bindingValues_.value(key,0).toInt();
            const bool active=data.value("segmentIndex").toInt()<count;
            const auto ink=data.value("segmentStyle").toObject().value(active?"active":"inactive").toObject().value("fill");
            QJsonObject paint;paint["type"]="SOLID";paint["color"]=ink;paint["opacity"]=1;paint["visible"]=true;
            item->data["fills"]=QJsonArray{paint};
            for(auto &g:item->fills)g.paints=QJsonArray{paint};
            item->setOpacity(1);
        } else if(bindingValues_.contains(key)&&data.value("type")=="TEXT") {
            if(binding=="channel.distanceValue") {
                bool numeric=false;
                const double value=bindingValues_.value(key).toDouble(&numeric);
                item->text=numeric&&std::isfinite(value)&&value>=0?QString::number(value,'f',1):QStringLiteral("--");
            } else item->text=bindingValues_.value(key).toString();
        }
        item->setData(DisplayTextRole,data.value("type")=="TEXT"?
            (item->stateLabel.isValid()?item->stateLabel.toString():item->text):QString());
    }
}
namespace {
QVariantList visualState(const DesignItem *item) {
    QVariantList fills;
    // Geometry paints are what paint() consumes; JSON fills alone can be stale.
    // pos 参与比较：宿主若允许拖动节点，位移同样要产生 damage 覆盖旧像素。
    for(const auto &geometry:item->fills)fills.append(QVariant::fromValue(geometry.paints));
    return {item->stateLabel.isValid()?item->stateLabel.toString():item->text,
        item->stateInk,item->opacity(),item->isVisible(),item->hasReplacement,
        item->replacement.cacheKey(),QVariant(fills),item->switchOn,item->switchDisabled,
        item->pos(),
        item->fills.isEmpty()||item->data.value("type")=="TEXT"?item->data.value("fills").toVariant():QVariant()};
}
}
void DesignView::beginVisualUpdate() {
    if(visualUpdateDepth_++!=0)return;
    visualBefore_.clear();
    // 静态图层内容不参与视觉快照：既不变化，也不产生 damage。
    for(auto *item:dynamicItems_)
        visualBefore_.insert(item->data.value("id").toString(),visualState(item));
}
void DesignView::endVisualUpdate() {
    if(visualUpdateDepth_==1&&bindingRefreshPending_) {
        bindingRefreshPending_=false;
        applyBindingVisuals();
    }
    if(visualUpdateDepth_<=0||--visualUpdateDepth_!=0)return;
    bool changed=false;
    for(auto *item:dynamicItems_) {
        const QString id=item->data.value("id").toString();
        if(visualBefore_.value(id)==visualState(item))continue;
        if(six_profile::enabled()) {
            const auto before=visualBefore_.value(id),after=visualState(item);
            const QString binding=item->data.value("binding").toString();
            const QString index=QString::number(item->data.value("channelIndex").toInt(item->data.value("bindingIndex").toInt(-1)));
            // 无绑定的固定图元按 node id 归类，避免混进绑定统计。
            six_profile::keyed("visual.binding.",binding.isEmpty()
                ?QStringLiteral("node:")+id:binding+":"+index);
            static const char* const fields[]={"text","ink","opacity","visible","hasReplacement",
                "replacementKey","fills","switchOn","switchDisabled","pos","fillsJson"};
            const int fieldCount=int(sizeof(fields)/sizeof(fields[0]));
            for(int field=0;field<after.size()&&field<fieldCount;++field)
                if(field>=before.size()||before[field]!=after[field])
                    six_profile::keyed("visual.field.",QString::fromLatin1(fields[field]));
        }
        changed=true;
        bindingDamage_.append(item->mapRectToScene(item->boundingRect().united(item->childrenBoundingRect())).adjusted(-3,-3,3,3));
        item->update();
    }
    visualBefore_.clear();
    if(changed){six_profile::count("scene.visual_revision");++revision_;}
}
namespace {
QVector<DesignItem*> childItemsByZ(DesignItem *parent) {
    QVector<DesignItem*> children;
    for(auto *child:parent->childItems())
        if(auto *design=dynamic_cast<DesignItem*>(child))children.append(design);
    // Qt 先按 z 从小到大绘制；同 z 保持插入顺序，与 addNode 的赋值方式一致。
    std::stable_sort(children.begin(),children.end(),[](DesignItem *a,DesignItem *b){
        return a->zValue()<b->zValue();});
    return children;
}
bool effectivelyVisible(const QGraphicsItem *item) {
    for(;item;item=item->parentItem())if(!item->isVisible())return false;
    return true;
}
QRectF staticSubtreeBoundsInParent(DesignItem *root) {
    const QRectF bounds=root->boundingRect().united(root->childrenBoundingRect());
    const QRectF mapped=root->parentItem()?root->mapRectToParent(bounds):bounds;
    // 反锯齿描边可能超出几何包围盒半个像素。
    return mapped.adjusted(-1,-1,1,1);
}
void collectStaticSubtree(DesignItem *root,QVector<DesignItem*> &out) {
    out.append(root);
    for(auto *child:root->childItems())
        if(auto *design=dynamic_cast<DesignItem*>(child))collectStaticSubtree(design,out);
}
// 旋转/缩放过的内容在烘焙与直接绘制时由光栅器采样，边缘相位可能有亚像素差；
// 这类小段保持矢量绘制，保证与旧路径逐像素一致。
bool axisAlignedItem(const DesignItem *item) {
    const QTransform t=item->transform();
    return qFuzzyCompare(t.m11(),1.0)&&qFuzzyCompare(t.m22(),1.0)&&
        qFuzzyIsNull(t.m12())&&qFuzzyIsNull(t.m21());
}
// 与 QGraphicsScene 的绘制顺序一致：z<0 的子项先于自身内容，z>=0 的随后；
// 透明度按祖先链累乘。ItemClipsChildrenToShape 只裁剪子项，不裁剪自身内容。
void paintStaticSubtree(QPainter *painter,DesignItem *item) {
    if(!effectivelyVisible(item))return;
    painter->save();
    painter->setTransform(item->itemTransform(item->parentItem()),true);
    painter->setOpacity(painter->opacity()*item->opacity());
    const bool clipChildren=item->flags()&QGraphicsItem::ItemClipsChildrenToShape;
    const auto children=childItemsByZ(item);
    const auto paintChild=[&](DesignItem *child){
        painter->save();
        if(clipChildren)painter->setClipPath(item->shape(),Qt::IntersectClip);
        paintStaticSubtree(painter,child);
        painter->restore();
    };
    for(auto *child:children)if(child->zValue()<0)paintChild(child);
    item->paint(painter,nullptr,nullptr);
    for(auto *child:children)if(child->zValue()>=0)paintChild(child);
    painter->restore();
}
}

qreal DesignView::preferredStaticLayerScale() const {
    if(staticLayerScaleOverride_>0)return staticLayerScaleOverride_;
    if(!scene())return 1.0;
    const QRectF rect=scene()->sceneRect();
    if(rect.isEmpty())return 1.0;
    // 按宿主实际离屏输出的像素尺寸烘焙，避免整页图片重采样。
    qreal scale=qMin(staticRenderSize_.width()/rect.width(),staticRenderSize_.height()/rect.height());
    // 被当普通控件显示时，视口更大就跟着提高分辨率；板端是离屏场景，不会走到这里。
    if(isVisible()&&viewport())
        scale=qMax(scale,qMin(viewport()->width()/rect.width(),viewport()->height()/rect.height()));
    if(isVisible())if(auto *screen=QGuiApplication::primaryScreen())
        scale*=screen->devicePixelRatio();
    return qBound(0.1,scale,4.0);
}
QPointF DesignView::staticLayerDeviceOrigin(qreal scale) const {
    // 宿主按 KeepAspectRatio 居中铺到输出纹理；用同一原点推导像素栅格，
    // 图层像素才能与矢量绘制同相位。视口可见时不假设输出尺寸。
    if(isVisible()||!scene())return QPointF(0,0);
    const QRectF rect=scene()->sceneRect();
    return QPointF((staticRenderSize_.width()-rect.width()*scale)/2,(staticRenderSize_.height()-rect.height()*scale)/2);
}
void DesignView::rebuildPagePreservingBindings() {
    if(pageIndex_<0)return;
    const auto bindings=bindingValues_;
    setPage(pageIndex_);
    setBindings(bindings);
}
void DesignView::setStaticRenderSize(const QSize &pixels) {
    if(pixels.isEmpty()||pixels==staticRenderSize_)return;
    staticRenderSize_=pixels;
    if(retiredStaticNodes_>0){rebuildPagePreservingBindings();return;}
    invalidateStaticLayers();ensureStaticLayers();
}
void DesignView::setStaticLayerScale(qreal scale) {
    staticLayerScaleOverride_=qMax(0.0,scale);
    if(retiredStaticNodes_>0){rebuildPagePreservingBindings();return;}
    invalidateStaticLayers();
    ensureStaticLayers();
}
void DesignView::ensureStaticLayers() {
    if(pageIndex_<0||!scene()||scene()->sceneRect().isEmpty())return;
    // 现场排障开关：ADS_STATIC_LAYERS=0 时退回逐图元绘制。
    if(qEnvironmentVariableIsSet("ADS_STATIC_LAYERS")&&qEnvironmentVariableIntValue("ADS_STATIC_LAYERS")==0) {
        if(retiredStaticNodes_>0){rebuildPagePreservingBindings();return;}
        invalidateStaticLayers();
        return;
    }
    const qreal scale=preferredStaticLayerScale();
    // 只在首次生成、页面/尺寸变化、HUD 切换、覆盖内容变化或分辨率明显变化时重建，
    // 正常帧不生成缓存。
    if(staticLayersValid_&&bakedOverrideVersion_==overrideVersion_&&staticLayerScale_>0&&
        qAbs(scale-staticLayerScale_)<0.000001)return;
    if(retiredStaticNodes_>0){rebuildPagePreservingBindings();return;}
    rebuildStaticLayers(scale);
}
void DesignView::invalidateStaticLayers() {
    for(auto *item:staticLayerItems_) {
        if(auto *scene=item->scene())scene->removeItem(item);
        delete item;   // 图层图元由视图自己创建，不归场景所有
    }
    staticLayerItems_.clear();
    for(auto *item:items_) {
        if(!item->staticBaked)continue;
        item->staticBaked=false;
        item->setFlag(QGraphicsItem::ItemHasNoContents,false);
    }
    staticLayersValid_=false;
}
void DesignView::rebuildStaticLayers(qreal scale) {
    QElapsedTimer timer;timer.start();
    invalidateStaticLayers();
    staticLayerScale_=qMax(0.1,scale);
    ++staticLayerRebuilds_;
    staticBakedNodes_=0;
    staticLayerBytes_=0;
    DesignItem *pageRoot=nullptr;
    for(auto *item:items_)
        if(!item->parentItem()){pageRoot=item;break;}
    if(!pageRoot) {
        staticLayersValid_=true;
        bakedOverrideVersion_=overrideVersion_;
        staticLayerBuildMs_=timer.nsecsElapsed()/1e6;
        return;
    }
    std::function<void(DesignItem*)> walk=[&](DesignItem *parent) {
        const auto children=childItemsByZ(parent);
        int index=0;
        while(index<children.size()) {
            if(children[index]->subtreeDynamic) {
                walk(children[index]);
                ++index;
                continue;
            }
            // 连续静态兄弟合成一段；动态兄弟会把 z 段切断，前后顺序不变。
            QVector<DesignItem*> run;
            const qreal z=children[index]->zValue();
            while(index<children.size()&&!children[index]->subtreeDynamic) {
                run.append(children[index]);
                ++index;
            }
            bakeBand(run,parent,z,staticLayerScale_);
        }
    };
    walk(pageRoot);
    retireStaticNodes();
    staticLayersValid_=true;
    bakedOverrideVersion_=overrideVersion_;
    staticLayerBuildMs_=timer.nsecsElapsed()/1e6;
}
void DesignView::bakeBand(const QVector<DesignItem*> &roots,DesignItem *parent,qreal z,qreal scale) {
    QRectF bounds;
    QVector<DesignItem*> baked;
    for(auto *root:roots) {
        collectStaticSubtree(root,baked);
        if(!effectivelyVisible(root))continue;
        const QRectF part=staticSubtreeBoundsInParent(root);
        if(part.isEmpty())continue;
        bounds=bounds.united(part);
    }
    if(baked.isEmpty())return;
    if(!parent->action.isEmpty()||!parent->data.value("interaction").toObject().isEmpty())return;
    if(bounds.isEmpty()) {
        for(auto *item:baked)item->staticBaked=true;
        staticBakedNodes_+=baked.size();return;
    }
    for(auto *item:baked)
        if(!axisAlignedItem(item))return;
    // 只在轴对齐的父层烘焙：非轴对齐时图片会在渲染期被旋转/缩放重采样，
    // 既拿不到 1:1 拷贝，也可能与矢量绘制出现相位差，直接保留逐图元绘制。
    const QTransform parentScene=parent->sceneTransform();
    if(!qFuzzyCompare(parentScene.m11(),1.0)||!qFuzzyCompare(parentScene.m22(),1.0)||
       !qFuzzyIsNull(parentScene.m12())||!qFuzzyIsNull(parentScene.m21()))return;
    // 单段分辨率上限：异常大的节点宁可不合并（继续逐图元绘制），也不吃爆内存。
    const qreal maxSide=4096.0;
    const qreal sideFit=qMin(1.0,qMin(maxSide/(bounds.width()*scale),maxSide/(bounds.height()*scale)));
    const qreal effective=scale*sideFit;
    const QPointF origin=staticLayerDeviceOrigin(effective);
    // 把图层像素对齐到“板端 1920x1080 居中 fit”的设备栅格：位图与矢量在同一
    // 采样相位上，渲染期可按整数像素 1:1 拷贝，静态边缘不会被二次重采样。
    const qreal cx=parentScene.dx(),cy=parentScene.dy();
    const int pixelLeft=int(std::floor(origin.x()+effective*(bounds.left()+cx)));
    const int pixelTop=int(std::floor(origin.y()+effective*(bounds.top()+cy)));
    const int pixelRight=int(std::ceil(origin.x()+effective*(bounds.right()+cx)));
    const int pixelBottom=int(std::ceil(origin.y()+effective*(bounds.bottom()+cy)));
    const QSize pixelSize(qMax(1,pixelRight-pixelLeft),qMax(1,pixelBottom-pixelTop));
    const qint64 pixelCount=qint64(pixelSize.width())*pixelSize.height();
    if(pixelCount>8LL*1024*1024)return;
    // 大面积、少节点的“大底板”保持矢量绘制：整幅 alpha 混合比直接填色更贵，
    // 合并只对图标/文字密集的小段有收益。两者都按像素面积粗算，避免误判。
    if(pixelCount>300000 && pixelCount>qint64(baked.size())*30000)return;
    const QRectF bandRect((pixelLeft-origin.x())/effective-cx,(pixelTop-origin.y())/effective-cy,
        pixelSize.width()/effective,pixelSize.height()/effective);
    // Match the host's chrome format to avoid an extra raster-format mismatch.
    QImage image(pixelSize,QImage::Format_RGBA8888_Premultiplied);
    image.fill(Qt::transparent);
    {
        QPainter painter(&image);
        painter.setRenderHint(QPainter::Antialiasing);
        painter.setRenderHint(QPainter::SmoothPixmapTransform);
        painter.setRenderHint(QPainter::TextAntialiasing);
        painter.scale(effective,effective);
        painter.translate(-bandRect.left(),-bandRect.top());
        for(auto *root:roots)paintStaticSubtree(&painter,root);
    }
    if(qEnvironmentVariableIntValue("ADS_STATIC_LAYER_DEBUG")>=2) {
        const QString dir=qEnvironmentVariable("ADS_STATIC_LAYER_DUMP_DIR");
        if(!dir.isEmpty()) {
            QString name=parent->data.value("id").toString();
            name.replace(':','_');
            image.save(dir+QStringLiteral("/band_%1_%2_%3.png")
                .arg(currentPageKey()).arg(name).arg(staticLayerItems_.size()));
        }
    }
    auto *band=new StaticLayerItem(QRectF(0,0,pixelSize.width()/effective,pixelSize.height()/effective),image);
    band->setParentItem(parent);
    band->setPos(bandRect.topLeft());
    band->setZValue(z);
    staticLayerItems_.append(band);
    for(auto *item:baked) {
        item->staticBaked=true;
        // 标记后在整页烘焙结束时移除，素材与定位已保存成独立数据。
        item->setFlag(QGraphicsItem::ItemHasNoContents,true);
    }
    staticBakedNodes_+=baked.size();
    staticLayerBytes_+=qint64(pixelSize.width())*pixelSize.height()*4;
    if(qEnvironmentVariableIsSet("ADS_STATIC_LAYER_DEBUG"))
        fprintf(stderr,"[static-layer] page=%s parent=%s roots0=%s roots=%d nodes=%d bounds=(%.2f,%.2f,%.2fx%.2f) image=%dx%d band=(%.2f,%.2f) T=%d L=%d e=%.6f o=(%.2f,%.2f) z=%.0f\n",
            qPrintable(currentPageKey()),qPrintable(parent->data.value("id").toString()),
            qPrintable(roots.isEmpty()?QString():roots.first()->data.value("id").toString()),
            int(roots.size()),int(baked.size()),bounds.x(),bounds.y(),bounds.width(),bounds.height(),
            pixelSize.width(),pixelSize.height(),bandRect.x(),bandRect.y(),pixelTop,pixelLeft,
            effective,origin.x(),origin.y(),z);
}
void DesignView::fitPage(){
    if(!hud_ && pageIndex_>=0 && pageIndex_<pages_.size()) {
        const auto page=pages_[pageIndex_].toObject();
        QBrush background(QColor("#080f14"));
        for(const auto &v:page.value("fills").toArray()) {
            const auto paint=v.toObject();
            if(paint.value("visible").toBool(true) && paint.value("type")=="SOLID") {
                background=paintBrush(paint,scene()->sceneRect());break;
            }
        }
        setBackgroundBrush(background);
    }
    if(!scene()->sceneRect().isEmpty())fitInView(scene()->sceneRect(),Qt::KeepAspectRatio);
    // 页面/尺寸确定后生成一次静态图层，后续帧直接复用。
    ensureStaticLayers();
}
void DesignView::resizeEvent(QResizeEvent *event){QGraphicsView::resizeEvent(event);fitPage();}
