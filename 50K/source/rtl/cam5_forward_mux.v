`timescale 1ns/1ps
// Four-word lookahead reserves only redundant legacy timing words. Pixels,
// timing transitions and skip guards are never replaced by control symbols.
module cam5_forward_mux(
    input clk,rst_n,input [31:0] video_data,input [3:0] video_k,
    input control_valid,output control_ready,
    input [31:0] control_data,input [3:0] control_k,
    output reg [31:0] tx_data,output reg [3:0] tx_k
);
    reg [31:0] d0,d1,d2,last_timing;
    reg [3:0] k0,k1,k2;
    assign control_ready=k2==9 && k1==9 && k0==9 && video_k==9 &&
        d2==d1 && d2==d0 && d2==video_data && d2==last_timing;
    always @(posedge clk or negedge rst_n)
        if(!rst_n) begin
            d0<=32'hbc0028bc;d1<=32'hbc0028bc;d2<=32'hbc0028bc;
            k0<=9;k1<=9;k2<=9;last_timing<=32'hbc0028bc;
            tx_data<=32'hbc0028bc;tx_k<=9;
        end else begin
            d0<=video_data;d1<=d0;d2<=d1;k0<=video_k;k1<=k0;k2<=k1;
            tx_data<=d2;tx_k<=k2;
            if(k2==9) last_timing<=d2;
            if(control_valid && control_ready) begin tx_data<=control_data;tx_k<=control_k;end
        end
endmodule
