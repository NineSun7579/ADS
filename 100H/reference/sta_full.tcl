set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG484
report_timing -input_db_file {C:/nh_build/v10_lane_io_ctrlchain8_20261103/work_ctrlchain8_seed62/place_route/top_pnr.adf} -force_to_run -delay_type min_max -nworst 1 -max_path 15000 -input_pins TRUE -report_exception TRUE
exit
