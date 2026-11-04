#ifndef LANE_DRIVING_RULES_LANE_CHANGE_H_
#define LANE_DRIVING_RULES_LANE_CHANGE_H_

#include <cstdint>
#include <functional>
#include <limits>
#include <utility>

namespace ads_lane_rules {

// 与视觉输出类别编号一致；0 和越界值不是有效输入。
enum class LaneMarking {
    DOUBLE_YELLOW = 1,
    DOUBLE_WHITE = 2,
    SINGLE_YELLOW = 3,
    SINGLE_WHITE = 4,
    DASHED_YELLOW = 5,
    DASHED_WHITE = 6,
    OTHER = 7,
    CROSSWALK = 8,
};

enum class Request { NONE, LEFT, RIGHT };
enum class Signal { OFF, LEFT, RIGHT };

enum class Decision {
    UNKNOWN,
    ALLOWED,
    SOLID_FORBIDDEN,
    NO_LANE,
    UNSAFE_TRAFFIC,
    INVALID_INPUT,
};

struct Boundary {
    bool adjacent_lane_exists = false;
    bool geometry_valid = false;
    LaneMarking marking = LaneMarking::OTHER;
};

struct LaneChangeInput {
    Request request = Request::NONE;
    Boundary left;
    Boundary right;

    // 没有可靠的整车状态时必须保持 false，禁止用缺省值推断可变道。
    bool vehicle_state_valid = false;
    bool lane_centered = false;
    bool changing_lane = false;
    bool crossing_tracked = false;

    // 仅表示目标车道已完成跨线；没有跨线追踪时必须保持 false。
    bool target_lane_reached = false;

    // traffic_clear 仅在 traffic_known 为 true 时有意义。
    bool traffic_known = false;
    bool traffic_clear = false;
};

inline bool valid_marking(LaneMarking marking) {
    const int value = static_cast<int>(marking);
    return value >= 1 && value <= 8;
}

inline bool is_solid(LaneMarking marking) {
    return marking == LaneMarking::DOUBLE_YELLOW ||
           marking == LaneMarking::DOUBLE_WHITE ||
           marking == LaneMarking::SINGLE_YELLOW ||
           marking == LaneMarking::SINGLE_WHITE;
}

// The marking restriction is observable independently of vehicle motion and
// rear traffic. A dashed line permits consideration, never proves a safe move.
enum class BoundaryPermission { UNKNOWN, SOLID_FORBIDDEN, DASHED_CONDITIONAL };
inline BoundaryPermission assess_boundary(bool geometry_valid,LaneMarking marking) {
    if(!geometry_valid || !valid_marking(marking))return BoundaryPermission::UNKNOWN;
    if(is_solid(marking))return BoundaryPermission::SOLID_FORBIDDEN;
    if(marking==LaneMarking::DASHED_YELLOW || marking==LaneMarking::DASHED_WHITE)
        return BoundaryPermission::DASHED_CONDITIONAL;
    return BoundaryPermission::UNKNOWN;
}

inline Decision evaluate(const LaneChangeInput& input) {
    if (input.request != Request::LEFT && input.request != Request::RIGHT) {
        return Decision::INVALID_INPUT;
    }
    if (!input.vehicle_state_valid) {
        return Decision::INVALID_INPUT;
    }

    const Boundary& boundary =
        input.request == Request::LEFT ? input.left : input.right;
    if (!boundary.adjacent_lane_exists) {
        return Decision::NO_LANE;
    }
    if (!boundary.geometry_valid || !valid_marking(boundary.marking)) {
        return Decision::INVALID_INPUT;
    }

    if (!input.changing_lane && input.target_lane_reached) {
        return Decision::INVALID_INPUT;
    }
    if (is_solid(boundary.marking)) {
        return Decision::SOLID_FORBIDDEN;
    }
    if (boundary.marking != LaneMarking::DASHED_YELLOW &&
        boundary.marking != LaneMarking::DASHED_WHITE) {
        return Decision::UNKNOWN;
    }
    // 重新评估变道途中场景：实线在上方直接禁止，无跨线追踪则拒读。
    if ((input.changing_lane && !input.crossing_tracked) ||
        (!input.changing_lane && !input.lane_centered)) {
        return Decision::UNKNOWN;
    }
    if (!input.traffic_known || !input.traffic_clear) {
        return Decision::UNSAFE_TRAFFIC;
    }
    return Decision::ALLOWED;
}

inline Signal signal_for(Request request) {
    if (request == Request::LEFT) {
        return Signal::LEFT;
    }
    if (request == Request::RIGHT) {
        return Signal::RIGHT;
    }
    return Signal::OFF;
}

// 调用方负责线程同步，并使用同一个单调毫秒时钟；回调内不得重入本对象。
class SignalController {
public:
    using Callback = std::function<void(Signal)>;

    void set_callback(Callback callback) {
        callback_ = std::move(callback);
    }

    // 成功登记一次输出请求即调用回调；timeout_ms=0 表示立即关闭。
    void request(Signal signal, std::uint32_t timeout_ms,
                 std::uint64_t now_ms) {
        if (signal == Signal::OFF || timeout_ms == 0) {
            stop();
            return;
        }
        const std::uint64_t max = std::numeric_limits<std::uint64_t>::max();
        deadline_ms_ = timeout_ms > max - now_ms
                           ? max
                           : now_ms + static_cast<std::uint64_t>(timeout_ms);
        active_ = true;
        notify(signal);
    }

    void update(std::uint64_t now_ms) {
        if (active_ && now_ms >= deadline_ms_) {
            stop();
        }
    }

    void stop() {
        active_ = false;
        notify(Signal::OFF);
    }

private:
    void notify(Signal signal) {
        if (callback_) {
            callback_(signal);
        }
    }

    Callback callback_;
    bool active_ = false;
    std::uint64_t deadline_ms_ = 0;
};

}  // namespace driving_rules

#endif  // LANE_DRIVING_RULES_LANE_CHANGE_H_
