#pragma once
#include <cstdint>
namespace cam1 {
enum class WatchdogAction { Wait, RestartProcess, HoldRuntime };
inline WatchdogAction watchdogAction(bool paused,bool switching,bool fault,bool hardwareHd,
                                     int64_t silentMs,int64_t timeoutMs) {
    if(paused || switching || fault || silentMs<timeoutMs) return WatchdogAction::Wait;
    return hardwareHd ? WatchdogAction::HoldRuntime : WatchdogAction::RestartProcess;
}
// A successful configuration may precede publication failure. The software
// geometry follows the target until rollback is actually verified.
inline bool modeAfterRollback(bool previous,bool target,bool verified) {
    return verified ? previous : target;
}
}
