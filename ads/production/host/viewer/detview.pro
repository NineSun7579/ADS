QT       += core gui widgets
CONFIG   += c++17
CONFIG   += link_pkgconfig
PKGCONFIG += opencv4
TARGET = detview_motion_cam134
HEADERS += ads_postprocess.h lane6_d3a_view.h seg_post_c.h
HEADERS += async_pipeline_selftest.h
HEADERS += ads_driving_adapter.h driving_lane_change.h driving_traffic_permission.h
HEADERS += ads_state_machine/vehicle_action_state.h ads_state_machine/aeb_trajectory.h \
           ads_state_machine/navigation_signal.h ads_state_machine/json_session.h \
           vehicle_action_state.h mono_motion.h mono_estimator.h
HEADERS += local_video_input.h hdmi_frame.h
HEADERS += hdmi_fisheye_contract.h hdmi_fisheye_publisher.h
HEADERS += hdmi_display_gamma.h
fisheyelive.path = $$OUT_PWD
fisheyelive.files = $$PWD/hdmi_fisheye_live.py
COPIES += fisheyelive
HEADERS += lane_arbitration.h lane_scene.h lane_preview.h lane_style.h detection_style.h \
           driving_visual_evidence.h driving_rules_config.h
TEMPLATE  = app
INCLUDEPATH += $$PWD/third_party/ranging_cpu/vendor
HEADERS += cpu_ranging.h third_party/ranging_cpu/ranging.hpp \
           third_party/ranging_cpu/vendor/lane_calib.h third_party/ranging_cpu/vendor/online_calib.h
HEADERS += stable_cpu_ranging.h
HEADERS += cpu_lateral_evidence.h
HEADERS += cpu_distance_quality.h
HEADERS += nav_ranging.h
SOURCES += nav_ranging.cpp
navmodels.path = $$OUT_PWD/navlite/models
navmodels.files = $$PWD/third_party/navlite/models/base.yml $$PWD/third_party/navlite/models/reject.yml
COPIES += navmodels
HEADERS += traffic_light_temporal.h traffic_light_view.h
SOURCES  += main-bev.cpp vision_pipeline.cpp vision_pipeline_selftest.cpp template_tracker.cpp \
            template_tracker_selftest.cpp stereo_demo/stereo_depth.cpp camera_dma_selftest.cpp \
            frame_metrics_selftest.cpp calibration_capture.cpp hdmi_view_selftest.cpp inference_geometry_selftest.cpp mvp_decode_selftest.cpp detection_temporal_filter_selftest.cpp
HEADERS += fpga_infer_input.h scheme2_uapi.h scheme2_verify.h scheme2_contract.h vision_types.h vision_pipeline.h template_tracker.h stereo_demo/stereo_depth.h \
           detview_ui.h exact_ui.h \
           stereo_demo/stereo_pairing.h camera_dma.h frame_metrics.h display_perf.h calibration_capture.h \
           hdmi_view.h inference_geometry.h mvp_decode.h mvp_round1_policy.h detection_temporal_filter.h
LIBS += -lrknnrt -lrga

# Figma 转换的 Qt Widgets 工程：作为 HUD 叠加层编译进宿主
SOURCES += ui/designview.cpp ui/businesscontroller.cpp
HEADERS += ui/designview.h ui/businesscontroller.h
# 设计资源改为运行时从 ui/assets 读取，避免 6.8MB 资源对象在板端编译

SOURCES += cam34_six_selftest.cpp surround_engine.cpp
HEADERS += surround_engine.h bird_boundary.h stereo_selection.h
HEADERS += cam34_six.h
SOURCES += cam1_runtime_selftest.cpp
HEADERS += cam1_runtime.h
HEADERS += cam1_runtime_safety.h
HEADERS += runtime_camera_geometry.h
HEADERS += fpga_lane_record.h
SOURCES += motion_policy_selftest.cpp
HEADERS += motion_abi.h motion_policy.h motion_policy_selftest.h capture_pacing.h motion_device_members.inc
HEADERS += bev_lane_calibration.h bev_lane.h bev_lane_worker.h bev_native_roi.h bev_native_lut.h bev_fpga_result.h
HEADERS += integrated_motion.h host_motion_abi.h
contains(CONFIG, runtime_ui_test) {
    TARGET = runtime_ui_test
    DEFINES += DETVIEW_RUNTIME_TEST_ONLY
    QMAKE_CXXFLAGS_RELEASE -= -O2
    QMAKE_CXXFLAGS_RELEASE += -O0
}
