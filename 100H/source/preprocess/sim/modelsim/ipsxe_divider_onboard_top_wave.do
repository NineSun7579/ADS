onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /ipsxe_divider_onboard_top_tb/u_ipsxe_divider_onboard_top/u_the_instance_name/i_aclk
add wave -noupdate /ipsxe_divider_onboard_top_tb/u_ipsxe_divider_onboard_top/u_the_instance_name/i_axi4s_divisor_tvalid
add wave -noupdate /ipsxe_divider_onboard_top_tb/u_ipsxe_divider_onboard_top/u_the_instance_name/o_axi4s_divisor_tready
add wave -noupdate /ipsxe_divider_onboard_top_tb/u_ipsxe_divider_onboard_top/u_the_instance_name/i_axi4s_divisor_tdata
add wave -noupdate /ipsxe_divider_onboard_top_tb/u_ipsxe_divider_onboard_top/u_the_instance_name/i_axi4s_dividend_tvalid
add wave -noupdate /ipsxe_divider_onboard_top_tb/u_ipsxe_divider_onboard_top/u_the_instance_name/i_axi4s_dividend_tdata
add wave -noupdate /ipsxe_divider_onboard_top_tb/u_ipsxe_divider_onboard_top/u_the_instance_name/o_axi4s_dividend_tready
add wave -noupdate /ipsxe_divider_onboard_top_tb/u_ipsxe_divider_onboard_top/u_the_instance_name/o_axi4s_dout_tvalid
add wave -noupdate /ipsxe_divider_onboard_top_tb/u_ipsxe_divider_onboard_top/u_the_instance_name/o_axi4s_dout_tdata
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {3840000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {3600007 ps} {4290839 ps}
