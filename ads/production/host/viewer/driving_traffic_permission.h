#ifndef LANE_TRAFFIC_PERMISSION_H
#define LANE_TRAFFIC_PERMISSION_H
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <functional>
#include <vector>
namespace ads_traffic_rules {
enum class Direction { Left, Straight, Right, UTurn };
enum class Permission { Unknown, Allowed, Stop, NotApplicable };
enum class LightColor { Unknown, Red, Yellow, Green };
enum class LightShape { Circular, LeftArrow, StraightArrow, RightArrow, UTurnArrow };
struct Box { double x=0, y=0, width=0, height=0; };
struct TrafficLight {
 Box box; LightColor color=LightColor::Unknown; LightShape shape=LightShape::Circular;
 double confidence=0; std::int64_t timestamp_ms=0; bool is_ahead=false; double distance_m=0;
};
// 类别：1双黄 2双白 3单黄 4单白 5黄虚线 6白虚线 7其它 8斑马线。
struct LaneMarking {
 int category=0; std::vector<Direction> lane_directions; bool selected_lane=false; bool has_stop_line=false;
};
struct RuleInput { bool allow_right_on_red=false; bool allow_uturn=false; };
struct Scene {
 std::vector<TrafficLight> lights; std::vector<LaneMarking> markings; std::int64_t timestamp_ms=0; RuleInput rules;
};
struct Output {
 Permission left=Permission::Unknown, straight=Permission::Unknown, right=Permission::Unknown, uturn=Permission::Unknown;
 bool traffic_light_presence=false; LightColor traffic_light_color=LightColor::Unknown; bool stop_line=false, crosswalk=false;
};
struct Options {
 double min_confidence=.5, max_distance_m=120; std::int64_t max_light_age_ms=500;
 double duplicate_iou=.5, associate_center_distance=.35;
};
struct ConfirmedGroup {
 Box box;LightColor color=LightColor::Unknown;bool confirmed=false,current=false;
 std::int64_t captured_ms=-1;
};
class TrafficPermission {
  public:
  // Explicit temporal evidence; raw confidence is never fabricated to bypass
  // the legacy single-frame score gate. Missing slots remain unknown.
  Output evaluateConfirmed(const std::vector<ConfirmedGroup>& evidence,std::int64_t now,
                           bool mapping_confirmed) const {
   Output out;if(!mapping_confirmed||evidence.empty()||evidence.size()>3)return out;
   const auto current=[&](const ConfirmedGroup& g){return g.confirmed&&g.current&&now>=g.captured_ms&&
       now-g.captured_ms<=options_.max_light_age_ms&&g.box.width>0&&g.box.height>0&&
       std::isfinite(g.box.x)&&std::isfinite(g.box.y)&&std::isfinite(g.box.width)&&std::isfinite(g.box.height);};
   const auto permission=[&](const ConfirmedGroup& g){
    if(!current(g))return Permission::Unknown;
    return g.color==LightColor::Green?Permission::Allowed:
       g.color==LightColor::Red||g.color==LightColor::Yellow?Permission::Stop:Permission::Unknown;
   };
   out.traffic_light_presence=true;out.left=permission(evidence[0]);
   out.straight=permission(evidence[evidence.size()==1?0:1]);
   out.right=evidence.size()==3?permission(evidence[2]):Permission::Allowed;
   return out;
  }
 // User-defined count policy, separate from the original arrow/lane policy.
 // Caller confirms that the supplied set is complete and belongs ahead.
 Output evaluateCount(std::vector<TrafficLight> lights, std::int64_t now,
                      bool ahead_set_confirmed) const {
  Output out;
  if(!ahead_set_confirmed || lights.empty()) return out;
  std::vector<TrafficLight> groups;
  for(const auto& l:lights) {
   if(!l.is_ahead || !std::isfinite(l.confidence) || l.confidence<options_.min_confidence ||
      !std::isfinite(l.box.x) || !std::isfinite(l.box.y) || !std::isfinite(l.box.width) ||
      !std::isfinite(l.box.height) || l.box.width<=0 || l.box.height<=0 ||
      now<l.timestamp_ms || now-l.timestamp_ms>options_.max_light_age_ms) return out;
   auto duplicate=std::find_if(groups.begin(),groups.end(),[&](const auto& v){
    return iou(v.box,l.box)>=options_.duplicate_iou;
   });
   if(duplicate==groups.end()) groups.push_back(l);
   else if(duplicate->color!=l.color) duplicate->color=LightColor::Unknown;
  }
  if(groups.empty() || groups.size()>3) return out;
  std::sort(groups.begin(),groups.end(),[](const auto& a,const auto& b){
   return a.box.x+a.box.width/2 < b.box.x+b.box.width/2;
  });
  // Ambiguous horizontal ordering cannot establish left/straight/right.
  for(size_t i=1;i<groups.size();++i)
   if(groups[i].box.x+groups[i].box.width/2 <= groups[i-1].box.x+groups[i-1].box.width/2)
    return out;
  const auto permission=[](LightColor c) {
   if(c==LightColor::Green) return Permission::Allowed;
   if(c==LightColor::Red || c==LightColor::Yellow) return Permission::Stop;
   return Permission::Unknown;
  };
  out.traffic_light_presence=true;
  out.left=permission(groups[0].color);
  out.straight=permission(groups[groups.size()==1?0:1].color);
  out.right=groups.size()<3?Permission::Allowed:permission(groups[2].color);
  if(groups.size()==1) out.traffic_light_color=groups[0].color;
  return out;
 }
 using Callback=std::function<void(const Output&)>;
 explicit TrafficPermission(Options options={}) : options_(options) {}
 void evaluate(const Scene& scene,const Callback& callback) const {
  Output out; std::vector<Direction> dirs; bool lane=false;
  for(const auto& m:scene.markings) {
   if(m.category==8) out.crosswalk=true;
   if(m.selected_lane) { lane=true; out.stop_line=out.stop_line||m.has_stop_line; dirs.insert(dirs.end(),m.lane_directions.begin(),m.lane_directions.end()); }
  }
  if(!lane) { callback(out); return; }
  for(auto d:{Direction::Left,Direction::Straight,Direction::Right,Direction::UTurn}) ref(out,d)=has(dirs,d)?Permission::Unknown:Permission::NotApplicable;
  std::vector<TrafficLight> valid;
  for(const auto& l:scene.lights) {
   if(!l.is_ahead||l.confidence<options_.min_confidence||!std::isfinite(l.distance_m)||l.distance_m<0||l.distance_m>options_.max_distance_m||l.box.width<=0||l.box.height<=0||scene.timestamp_ms<l.timestamp_ms||scene.timestamp_ms-l.timestamp_ms>options_.max_light_age_ms) continue;
   auto it=std::find_if(valid.begin(),valid.end(),[&](const TrafficLight& v){return v.shape==l.shape&&iou(v.box,l.box)>=options_.duplicate_iou;});
   if(it==valid.end()) valid.push_back(l);
   else if(it->color!=l.color) it->color=LightColor::Unknown;
   else if(l.confidence>it->confidence) *it=l;
  }
  out.traffic_light_presence=!valid.empty();
  if(valid.empty()) { callback(out); return; }
  for(auto d:{Direction::Left,Direction::Straight,Direction::Right,Direction::UTurn}) {
   Permission& p=ref(out,d); if(p==Permission::NotApplicable) continue;
   std::vector<LightColor> colors;
   for(const auto& l:valid) if(direction(l.shape)==d) colors.push_back(l.color);
   if(colors.empty()) for(const auto& l:valid) if(l.shape==LightShape::Circular&&associated(l,valid,d)) colors.push_back(l.color);
   if(colors.empty()) continue;
   if(std::any_of(colors.begin(),colors.end(),[](LightColor c){return c==LightColor::Unknown;})||std::any_of(colors.begin(),colors.end(),[&](LightColor c){return c!=colors.front();})) continue;
   out.traffic_light_color=colors.front();
   if(colors.front()==LightColor::Green) p=d==Direction::UTurn&&!scene.rules.allow_uturn?Permission::Unknown:Permission::Allowed;
   else if(colors.front()==LightColor::Red&&((d==Direction::Right&&scene.rules.allow_right_on_red)||(d==Direction::UTurn&&scene.rules.allow_uturn))) p=Permission::Allowed;
   else p=Permission::Stop;
  }
  callback(out);
 }
private:
 static bool has(const std::vector<Direction>& v,Direction d) { return std::find(v.begin(),v.end(),d)!=v.end(); }
 static Permission& ref(Output& o,Direction d) {
  switch(d) { case Direction::Left:return o.left; case Direction::Straight:return o.straight; case Direction::Right:return o.right; default:return o.uturn; }
 }
 static Direction direction(LightShape s) {
  switch(s) { case LightShape::LeftArrow:return Direction::Left; case LightShape::StraightArrow:return Direction::Straight; case LightShape::RightArrow:return Direction::Right; default:return Direction::UTurn; }
 }
 static double iou(const Box& a,const Box& b) {
  double w=std::max(0.0,std::min(a.x+a.width,b.x+b.width)-std::max(a.x,b.x));
  double h=std::max(0.0,std::min(a.y+a.height,b.y+b.height)-std::max(a.y,b.y));
  double in=w*h, den=a.width*a.height+b.width*b.height-in; return den>0?in/den:0;
 }
 bool associated(const TrafficLight& c,const std::vector<TrafficLight>& all,Direction d) const {
  double cx=c.box.x+c.box.width/2,cy=c.box.y+c.box.height/2,diag=std::hypot(c.box.width,c.box.height);
  for(const auto& l:all) if(l.shape!=LightShape::Circular&&direction(l.shape)!=d) {
   double dist=std::hypot(cx-l.box.x-l.box.width/2,cy-l.box.y-l.box.height/2);
   if(dist<=options_.associate_center_distance*std::max(diag,std::hypot(l.box.width,l.box.height))) return false;
  }
  return true;
 }
 Options options_;
};
}
#endif
