file delete -force work
file delete -force vsim_ipsxe_floating_point_onboard_top.log
vlib  work
vmap  work work
vlog -incr -sv \
-f ./ipsxe_divider_onboard_top_filelist.f  -l vlog.log
vsim {-voptargs=+acc} work.ipsxe_divider_onboard_top_tb -l sim.log
do ipsxe_divider_onboard_top_wave.do
run -all