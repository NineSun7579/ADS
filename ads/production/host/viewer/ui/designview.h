#pragma once
#include "businesscontroller.h"
#include <QGraphicsView>
#include <QJsonArray>
#include <QMap>
#include <QVector>
#include <QVariant>

class QGraphicsItem;
class DesignItem;
class DesignView final : public QGraphicsView {
    Q_OBJECT
public:
    explicit DesignView(QWidget *parent = nullptr, const QString &assetsDir = QString(), const QString &mode = QString());
    QStringList pageNames() const;
    QStringList pageIds() const;
    bool isLoaded() const { return !pages_.isEmpty(); }
    int currentPage() const { return pageIndex_; }
    // 稳定页面键：页面顺序可调整，业务不要依赖索引。
    QString currentPageKey() const;
public slots:
    void setPage(int index);
    void showPage(const QString &key);
    // HUD 叠加模式：透明背景、不画页面根底色，供上层 GL 视频透出
    void setHudMode(bool on);
    bool hudMode() const { return hud_; }
    void setNodeText(const QString &figmaNodeId, const QString &text);
    void setNodeImage(const QString &figmaNodeId, const QImage &image);
    // 所有 video 槽（binding=="frame"）在场景坐标下的矩形，供宿主挖空叠视频
    QVector<QRectF> frameRectsInScene() const;
    // 视频槽被挖空后，槽内的文字（目标标识/距离等）要单独补画，否则会被一起擦掉
    void paintSlotText(QPainter *painter, const QRectF &source, const QRectF &target) const;
    QMap<int, QRectF> channelRectsInScene() const;
    // 静态图元按 Figma 节点 id 直接查询（O(log n)）。只读叠加层用它定位区域和
    // 素材，避免每帧遍历整个场景；节点不存在时返回 nullptr。
    // 已烘焙并移除的静态节点返回 nullptr；定位和素材使用下面的数据接口。
    QGraphicsItem *nodeById(const QString &figmaId) const;
    // Immutable exported geometry/artwork survives removal of static scene nodes.
    QRectF nodeSceneRect(const QString &id) const;
    QImage nodeArtwork(const QString &id) const;
    int retiredStaticNodeCount() const { return retiredStaticNodes_; }
    // 静态图层诊断（离屏基准与现场排查用，不参与业务判定）。
    int staticLayerCount() const { return int(staticLayerItems_.size()); }
    int staticBakedNodeCount() const { return staticBakedNodes_; }
    int dynamicNodeCount() const { return int(dynamicItems_.size()); }
    qint64 staticLayerBytes() const { return staticLayerBytes_; }
    double staticLayerBuildMs() const { return staticLayerBuildMs_; }
    qreal staticLayerScale() const { return staticLayerScale_; }
    int staticLayerRebuildCount() const { return staticLayerRebuilds_; }
    // 每场景单位烘焙的设备像素数；<=0 表示按宿主输出尺寸推导。
    // 显式设置会立即失效当前静态图层。
    void setStaticLayerScale(qreal scale);
    void setStaticRenderSize(const QSize &pixels);
    // 渲染版本号：页面或显示文本变化时自增，供宿主缓存离屏渲染结果
    quint64 revision() const { return revision_; }
    QVector<QRectF> takeBindingDamage() { const auto result=bindingDamage_;bindingDamage_.clear();return result; }
    QString actionAtScene(const QPointF &point) const;
    void setPressedAction(const QString &action);
    void applyPerception(const PerceptionState &state);
    // Explicit visual outputs and gauge inputs, independent of sample text.
    void setBindingValue(const QString &binding, const QVariant &value, int channelIndex = -1);
    // Indexed statistics: bindingIndex 0..4, independent of node order.
    void setStatCounts(const QVector<int> &counts);
    // 批量写入绑定值（键自带 :channelIndex 后缀），只触发一次重绘
    void setBindings(const QMap<QString, QVariant> &values);
    // Compare the final visuals, not transient perception/binding overrides.
    void beginVisualUpdate();
    void endVisualUpdate();
signals:
    void actionTriggered(const QString &action);
    void pageChanged(int index);
protected:
    void resizeEvent(QResizeEvent *event) override;
    void mouseReleaseEvent(QMouseEvent *event) override;
    void mousePressEvent(QMouseEvent *event) override;
private:
    DesignItem *addNode(const QJsonObject &node, DesignItem *parent);
    void fitPage();
    void refreshBindingVisuals();
    void applyBindingVisuals();
    bool bindingRefreshPending_=false;
    // 静态图层：把“整棵子树都不随状态变化”的连续 z 段合并成一张图。
    void ensureStaticLayers();
    void invalidateStaticLayers();
    void rebuildStaticLayers(qreal scale);
    void bakeBand(const QVector<DesignItem *> &roots, DesignItem *parent, qreal z, qreal scale);
    qreal preferredStaticLayerScale() const;
    QPointF staticLayerDeviceOrigin(qreal scale) const;
    void collectSlotTextItems();
    void collectLegacyCountBindings();
    QMap<QString,QString> legacyCountBindings_;
    void captureArtwork();
    void retireStaticNodes();
    void rebuildPagePreservingBindings();
    QMap<QString,QRectF> nodeRects_;
    QMap<QString,QImage> nodeArtwork_;
    int retiredStaticNodes_=0;
    QMap<QString,QVariant> bindingValues_;
    QVector<QRectF> bindingDamage_;
    QMap<QString, QVariantList> visualBefore_;
    int visualUpdateDepth_ = 0;
    QString pressedAction_;
    QJsonArray pages_;
    QMap<QString, DesignItem *> items_;
    QMap<QString, QString> textOverrides_;
    QMap<QString, QImage> imageOverrides_;
    PerceptionState lastState_;
    bool hasState_ = false;
    quint64 revision_ = 0;
    int pageIndex_ = -1;
    bool hud_ = false;
    QString assetsDir_;
    // 动态图元（自身外观可能变化）与视频槽/槽内文字索引：刷新只看这些，不再全扫描。
    QVector<DesignItem *> dynamicItems_;
    QVector<DesignItem *> frameItems_;
    QVector<DesignItem *> slotTextItems_;
    QVector<QGraphicsItem *> staticLayerItems_;
    int staticBakedNodes_ = 0;
    int staticLayerRebuilds_ = 0;
    qint64 staticLayerBytes_ = 0;
    double staticLayerBuildMs_ = 0;
    qreal staticLayerScale_ = 0;
    qreal staticLayerScaleOverride_ = 0;
    QSize staticRenderSize_{1920,1080};
    bool staticLayersValid_ = false;
    int overrideVersion_ = 0;
    int bakedOverrideVersion_ = -1;
};
