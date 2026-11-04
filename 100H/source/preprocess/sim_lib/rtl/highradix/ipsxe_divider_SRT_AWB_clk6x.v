
module srt_awb_clk6x
#(
    parameter DIVIDEND_WIDTH = 8,
    parameter DIVISOR_WIDTH = 8,
    parameter FRACTION_WIDTH = 8
)
(
    input i_clk,
    input i_rst_n,
    input i_clken,
    input i_max,
    input [2'd3:1'b0] i_lut_d,
    input [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] i_w0,
    input [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] i_d,
    input [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] i_x,

    output [DIVIDEND_WIDTH+FRACTION_WIDTH+3'd5:1'b0]o_output_a,
    output [DIVIDEND_WIDTH+FRACTION_WIDTH+3'd5:1'b0]o_output_b,
    output [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0]o_output_w,
    output reg o_d_ready
);

    wire [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] i_w0_in;
    wire [DIVIDEND_WIDTH+FRACTION_WIDTH+3'd5:1'b0] a_in;
    wire [DIVIDEND_WIDTH+FRACTION_WIDTH+3'd5:1'b0] b_in;
    wire [9:1'b0] temp_1_in;
    wire [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] w0_in2;
    reg [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] w0_in_r;
    reg [DIVIDEND_WIDTH+FRACTION_WIDTH+3'd5:1'b0] a_in_r;
    reg [DIVIDEND_WIDTH+FRACTION_WIDTH+3'd5:1'b0] b_in_r;
    reg [9:1'b0] temp_1_in_r;
    reg [4'd10:1'b0] s_cnt; //state count;
    reg [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] w0_in_r2;
    wire state_clear;
    assign i_w0_in = w0_in_r;
    assign a_in = a_in_r;
    assign b_in = b_in_r;
    assign temp_1_in = temp_1_in_r;
    
reg [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] i_x_r;
reg [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] i_d_r;
reg [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] i_x_r2;
reg [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] i_d_r2;
    always@(posedge i_clk or negedge i_rst_n)
    begin
        if(!i_rst_n)begin
        i_x_r<=0;
        i_d_r<=0;
        i_x_r2<=0;
        i_d_r2<=0;
        end
        else if(i_clken)begin
        i_x_r<=i_x;
        i_d_r<=i_d;
        i_x_r2<=i_x_r;
        i_d_r2<=i_d_r;
        end
        else begin
        i_x_r<=i_x_r;
        i_d_r<=i_d_r;
        i_x_r2<=i_x_r2;
        i_d_r2<=i_d_r2;
        end
    end
    
wire change1;
wire change2;
assign change1=(i_x == i_x_r2)? 1'b0:1'b1;
assign change2=(i_d == i_d_r2)? 1'b0:1'b1;
assign state_clear=change1 || change2;


    always @(posedge i_clk or negedge i_rst_n)
    begin//srt_clk6x
        if(!i_rst_n)begin
            w0_in_r <={(DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd5){1'b0}} ;
            a_in_r <= {(DIVIDEND_WIDTH+FRACTION_WIDTH+3'd6){1'b0}};
            b_in_r <= {(DIVIDEND_WIDTH+FRACTION_WIDTH+3'd6){1'b0}};
            temp_1_in_r <= 0;
            s_cnt <= 10'b0;
            o_d_ready <= 1'b0;
        end
        else if (state_clear)begin
            w0_in_r <={(DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd5){1'b0}} ;
            a_in_r <= {(DIVIDEND_WIDTH+FRACTION_WIDTH+3'd6){1'b0}};
            b_in_r <= {(DIVIDEND_WIDTH+FRACTION_WIDTH+3'd6){1'b0}};
            temp_1_in_r <= 0;
            s_cnt <= 10'b0;
        end
        else if(i_clken)begin
            if(s_cnt == 10'd0)begin
                w0_in_r <= i_w0;
                a_in_r <= {(DIVIDEND_WIDTH+FRACTION_WIDTH+3'd6){1'b0}};
                b_in_r <= {(DIVIDEND_WIDTH+FRACTION_WIDTH+3'd6){1'b0}};
                o_d_ready <= 1'b0;
                temp_1_in_r <= 1'd1;
                s_cnt <= s_cnt + 1'd1;
            end
            else if (s_cnt == (DIVIDEND_WIDTH+FRACTION_WIDTH)/2'd2 - 1'b1)begin
                w0_in_r <= o_output_w;
                a_in_r <= o_output_a;
                b_in_r <= o_output_b;
                o_d_ready <= 1'b1;
                s_cnt <= 10'd0;
                temp_1_in_r <= temp_1_in_r + 1'd1;
            end
            else begin
                w0_in_r <= o_output_w;
                a_in_r <= o_output_a;
                b_in_r <= o_output_b;
                s_cnt <= s_cnt + 1'd1;
                temp_1_in_r <= temp_1_in_r + 1'd1;
            end
            end 
            else begin
                w0_in_r <= w0_in_r;
                a_in_r <= a_in_r;
                b_in_r <= b_in_r;
                s_cnt <= s_cnt;
                temp_1_in_r <= temp_1_in_r;
            
        end
    end

    output_ABW #(
            .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
            .DIVISOR_WIDTH(DIVISOR_WIDTH),
            .FRACTION_WIDTH(FRACTION_WIDTH)
        )  output_ABW_0(
        //input
        .i_w0(i_w0_in),
        .i_d(i_d),
        .i_lut_d(i_lut_d),
        .i_a(a_in),
        .i_b(b_in),
        .i_temp_1(temp_1_in),
        .i_max(i_max),
        //output
        .o_output_a(o_output_a),
        .o_output_b(o_output_b),
        .o_output_w(o_output_w)
    );


endmodule
