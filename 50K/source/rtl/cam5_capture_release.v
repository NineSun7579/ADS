`timescale 1ns/1ps
// Mode synchronizer reset is independent of capture and can remain released
// across SET/COMMIT. On any capture hold, assert BOTH ends of the relevant
// FIFOs using the common capture_request_n. Release locally in four edges
// after local_mode_rst_n: two mode-sampling edges plus two edges of margin.
// A stopped destination cannot release capture and creates no reset feedback.
module cam5_capture_release(
    input clk,local_mode_rst_n,capture_request_n,output capture_rst_n
);
    wire request_n=local_mode_rst_n && capture_request_n;
    wire first_release;
    video_reset_sync u_capture_reset(clk,request_n,first_release);
    video_reset_sync u_mode_settle_reset(clk,first_release,capture_rst_n);
endmodule
