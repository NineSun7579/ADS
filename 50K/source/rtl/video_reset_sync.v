`timescale 1ns/1ps
// Common assertion also works when the destination clock is unplugged.
module video_reset_sync(input clk, input request_n, output rst_n);
    (* ASYNC_REG = "TRUE" *) reg [1:0] release_q = 2'b00;
    // Only stage zero sees the asynchronous request. Stage one asserts from
    // stage zero even with a stopped clock; its release is locally timed.
    always @(posedge clk or negedge request_n)
        if (!request_n) release_q[0] <= 1'b0;
        else release_q[0] <= 1'b1;
    always @(posedge clk or negedge release_q[0])
        if (!release_q[0]) release_q[1] <= 1'b0;
        else release_q[1] <= 1'b1;
    assign rst_n = release_q[1];
endmodule
