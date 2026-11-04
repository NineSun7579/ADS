set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG484
add_constraint -physical -pcf {C:/nh_build/v10_lane_io_scratch_build_20261103/work_scratch_seed62/device_map/top.pcf}
pnr -input_db_file {C:/nh_build/v10_lane_io_scratch_build_20261103/work_scratch_seed62/device_map/top_map.adf} -force_to_run -gplace_seed 62 -slack_prior_in_global_router TRUE -logic_optimize_enable TRUE -optimize_multi_corner_timing -fix_hold_violation -fix_hold_violation_iterations 500 -fix_hold_violation_threshold 100 -fix_hold_violation_in_route TRUE -fix_hold_violation_threshold_for_clock_path_cross_srb 200 -fix_hold_violation_threshold_for_clk_tree 200 -max_hold_violated_paths_num 100000 -fast_router FALSE -max_ctrl_chain_length 8
exit
