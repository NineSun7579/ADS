#pragma once

#include "vision_types.h"
#include <QThread>
#include <QStringList>
#include <QHash>
#include <memory>
#include <functional>
#include <utility>
#include <cstddef>

// Public entry points are safe from the controller and capture threads. The
// QThread object stays in its owner's thread; all vision work runs in run().
class VisionPipeline : public QThread {
    Q_OBJECT
public:
    static constexpr quint64 FourRequest = quint64(1) << 63;
    explicit VisionPipeline(VisionOptions options, QObject* parent = nullptr);
    ~VisionPipeline() override;
    void submitFrame(const VisionFrame& frame);
    // Missing/empty model entries permit no template tracking. Class IDs are
    // detector-local; raw nonvehicle outputs retain padded Detection coordinates.
    void configure(int sourceGeneration, int selectedCamera, bool lane,
                   const QStringList& modelPaths,
                    const QHash<QString, QVector<int>>& vehicleClasses = {}, bool fourCamera = false);
    void submitDetections(QString modelPath, int sourceGeneration, quint64 frameId,
                           QVector<Detection> detections, double inferMs, quint64 epoch = 0, bool laneOnly = false);
    void inferenceFailed(int sourceGeneration, quint64 frameId, quint64 epoch);
    void inferenceFailed(int sourceGeneration, quint64 frameId);
    void stop();
    static bool selfTest();
signals:
    void inferenceRequested(VisionFrame frame, quint64 epoch);
    // One authoritative detector observation, before tracker/depth publication.
    void acceptedDetectorResult(QString modelPath, int sourceGeneration, quint64 sourceFrame,
                                 QVector<Detection> detections, qint64 acceptedMs, acquisition::Ticket acquisition);
    void tracksReady(QString modelPath, int sourceGeneration, quint64 frameId,
                      QVector<Detection> detections, double matchingMs, acquisition::Ticket acquisition);
    void stereoReady(int sourceGeneration, quint64 leftFrameId, QImage disparity,
                      QString status, acquisition::Ticket acquisition);
    void rangeReady(int sourceGeneration, int leftCamera, double meters,
                     qint64 capturedMs, bool trial, bool valid, QString status, acquisition::Ticket acquisition);
    void diagnostics(QString text);
protected:
    void run() override;
private:
    // Installed only by selfTest before start; callbacks run on the worker.
    void setSelfTestHook(std::function<void(int)> hook);
    void setSelfTestClock(std::function<qint64()> clock);
    bool selfTestHasProcessedFrame(const VisionFrame& frame) const;
    std::pair<size_t, quint64> selfTestReplayState() const;
    struct Impl;
    std::unique_ptr<Impl> d;
};
