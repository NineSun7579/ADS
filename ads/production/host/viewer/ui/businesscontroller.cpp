#include "businesscontroller.h"

BusinessController::BusinessController(QObject *parent) : QObject(parent) {
    qRegisterMetaType<PerceptionState>();
    qRegisterMetaType<ChannelState>();
}

void BusinessController::updatePerception(const PerceptionState &state) {
    state_ = state;
    emit perceptionChanged(state_);
}

void BusinessController::requestAction(const QString &action) {
    if (action.startsWith("page:")) {
        emit pageRequested(action.mid(5));
        return;
    }
    if (action != "drive" && action != "stop" && action != "lane:left" &&
        action != "lane:straight" && action != "lane:right" &&
        action != "change:left" && action != "change:right") return;
    const quint64 id = ++sequence_;
    pending_.insert(id, action);
    emit requestIssued(id, action);
    if (action == "drive") emit driveRequested(id);
    else if (action == "stop") emit stopRequested(id);
    else if (action.startsWith("lane:")) emit laneSelectionRequested(id, action.mid(5));
    else emit laneChangeRequested(id, action.mid(7));
}

void BusinessController::reportRequestResult(quint64 requestId, const QString &message) {
    if (!pending_.remove(requestId)) return;
    emit requestFinished(requestId, message);
}
