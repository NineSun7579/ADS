set_arch -family Logos -device PGL50H -speedgrade -6 -package FBG484
report_timing -input_db_file {C:/nh_build/s50v10c/seeds/seed_1_signoff/hdmi_ddr_ov5640_top_pnr.adf} -force_to_run -delay_type min_max -nworst 1 -max_path 15000 -input_pins TRUE -report_exception TRUE
exit
