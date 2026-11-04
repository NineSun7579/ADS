#pragma once
#include <QObject>
#include <QDateTime>
#include <QImage>
#include <QMap>
#include <QString>
#include <QVector>

// This model contains observations from your backend, never inferred permission.
struct ChannelState {
    QString name;
    QImage frame;
    QString targetLabel;
    double distanceMeters = -1;
    double fps = 0;
    bool connected = false;
    int distanceSegments = 0; // Explicit illuminated gauge segment count.
};
struct PerceptionState {
    QDateTime observedAt;
    QVector<ChannelState> channels;
    QMap<QString, int> objectCounts;
    QString trafficLight;
    QString nextAction;
    QString drivingStatus;
    double speedKph = -1;
    QMap<QString,QString> visualStates; // ui.* -> normal/active/disabled/warning.
};
Q_DECLARE_METATYPE(ChannelState)
Q_DECLARE_METATYPE(PerceptionState)

class BusinessController final : public QObject {
    Q_OBJECT
public:
    explicit BusinessController(QObject *parent = nullptr);
    const PerceptionState &state() const { return state_; }
public slots:
    // Connect backend signals to this slot (queued connection for worker threads).
    void updatePerception(const PerceptionState &state);
    void requestAction(const QString &action);
    // Called by your backend after it accepts/rejects/completes a request.
    void reportRequestResult(quint64 requestId, const QString &message);
signals:
    void perceptionChanged(const PerceptionState &state);
    void pageRequested(const QString &page);
    void driveRequested(quint64 requestId);
    void stopRequested(quint64 requestId);
    void laneSelectionRequested(quint64 requestId, const QString &direction);
    void laneChangeRequested(quint64 requestId, const QString &direction);
    void requestIssued(quint64 requestId, const QString &action);
    void requestFinished(quint64 requestId, const QString &message);
private:
    PerceptionState state_;
    quint64 sequence_ = 0;
    QMap<quint64, QString> pending_;
};
