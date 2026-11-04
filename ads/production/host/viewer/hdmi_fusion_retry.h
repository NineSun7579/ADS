#pragma once
#include <cstdint>

namespace hdmi_fusion {
// A worker restart never represents new captured work. Only a real output resets
// the failure streak; repeated launch failures back off even while input arrives.
class Retry {
public:
    int failed(std::int64_t now) {
        const int delay=m_delayMs;
        m_dueMs=now+delay;
        m_delayMs=m_delayMs<5000?m_delayMs*2:10000;
        return delay;
    }
    bool ready(std::int64_t now) const { return now>=m_dueMs; }
    void reset() { m_dueMs=0;m_delayMs=1000; }
private:
    std::int64_t m_dueMs=0;
    int m_delayMs=1000;
};
}
