set_arch -family Logos -device PGL50H -speedgrade -6 -package FBG484
add_constraint -physical -pcf {C:/nh_build/s50v10c/seeds/seed_1/device_map/hdmi_ddr_ov5640_top.pcf}
pnr -input_db_file {C:/nh_build/s50v10c/seeds/seed_1/device_map/hdmi_ddr_ov5640_top_map.adf} -force_to_run -gplace_seed 1 -optimize_multi_corner_timing -fix_hold_violation_in_route TRUE -fix_hold_violation_threshold 0
exit
