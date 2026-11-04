// Official Pango multiplier configured for lane-statistics 12x12 unsigned
// products. Input and output registers give a two-clock latency and keep the
// APM multiplier out of the candidate/accumulator combinational paths.
module lane_mult_u12 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [11:0] a,
    input  wire [11:0] b,
    output wire [23:0] p
);
    ipm2l_mult_v1_3_mul #(
        .ASIZE(12), .BSIZE(12), .OPTIMAL_TIMING(1),
        .INREG_EN(1), .PIPEREG_EN_1(0), .PIPEREG_EN_2(0), .PIPEREG_EN_3(0),
        .OUTREG_EN(1), .PIPE_STATUS(2), .ADVANCED_BOOL(0),
        .GRS_EN("FALSE"), .A_SIGNED(0), .B_SIGNED(0), .ASYNC_RST(0)
    ) u_mult (
        .ce(1'b1), .rst(!rst_n), .clk(clk), .a(a), .b(b), .p(p)
    );
endmodule
