#pragma once

#include <QImage>
#include <QMutex>
#include <QString>
#include <QThread>
#include <QWaitCondition>
#include <optional>

struct CalibrationCaptureJob {
    QImage left, right;
    int leftCamera = 0, rightCamera = 1; // Zero based, C1..C6.
    int generation = 0;
    quint64 leftSequence = 0, rightSequence = 0;
    quint32 leftTag = 0, rightTag = 0;
    // Same monotonic millisecond clock as camera capture (CLOCK_MONOTONIC on Linux).
    qint64 leftCapturedMs = 0, rightCapturedMs = 0, requestedMs = 0;
    double distanceMeters = 0; // Zero means unknown; a label, not a measured depth.
    QString outputRoot;
    bool synchronizationConfirmed = false, hasTagOffset = false;
    int tagOffset = 0; // leftTag == rightTag + offset, modulo 2^32.
};

// Call start() once, then submit() from any producer thread. No device access.
// One reservation covers snapshotting, detection, PNG writing and notification;
// submit returns false while busy/stopped or for malformed/stale input.
// Accepted jobs receive exactly one saved signal. path is the capture directory;
// capture.json is its completion marker. false can also mean saved rejection
// evidence: use path/message to distinguish that from an I/O failure.
class CalibrationCaptureWorker : public QThread {
    Q_OBJECT
public:
    explicit CalibrationCaptureWorker(QObject* parent = nullptr);
    ~CalibrationCaptureWorker() override;
    bool submit(CalibrationCaptureJob job);
    // Prevent further submissions and wake the worker. Finish an accepted job;
    // OpenCV is never interrupted. Owner may wait(); destruction calls stop/wait.
    void stop();
signals:
    void saved(int generation, QString path, QString message, bool pairUsable);
protected:
    void run() override;
private:
    QMutex mutex_;
    QWaitCondition changed_;
    std::optional<CalibrationCaptureJob> pending_;
    bool busy_ = false;
    bool stopping_ = false;
};

// Synthetic images and a temporary directory only. Returns 0 on success.
int runCalibrationCaptureSelfTest();
