
module srt4divider
#(
    parameter DIVIDEND_WIDTH = 8,
    parameter DIVISOR_WIDTH = 8,
    parameter FRACTION_WIDTH = 8
)
(
    input i_clk,i_rst_n,i_clken,i_f,
    input [DIVIDEND_WIDTH-1'b1:1'b0] i_x,
    input  [DIVISOR_WIDTH-1'b1:1'b0] i_d,
    output [DIVIDEND_WIDTH+FRACTION_WIDTH-1'b1:1'b0] o_q,
    output o_q_valid
);
    wire [DIVIDEND_WIDTH+3'd4:1'b0] o_x_shift;//m
    wire [DIVISOR_WIDTH+2'd2:1'b0] o_d_shift;//n
    wire [3'd5:1'b0] o_m,o_n;
    wire [2'd3:1'b0] i_lut_d;
    wire [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] i_w0;//4*w0,Partial remaini_der
    wire o_d_ready;
    wire [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] o_output_w;
    wire [DIVIDEND_WIDTH+FRACTION_WIDTH+3'd5:1'b0] o_output_a;
    wire [DIVIDEND_WIDTH+FRACTION_WIDTH+3'd5:1'b0] o_output_b;

    wire [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] o_d_shift_2;
    wire [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] o_x_shift_2;
    wire o_max;

    reg f1;
    reg[DIVIDEND_WIDTH+FRACTION_WIDTH+3'd5:1'b0] output_ab;
    reg[DIVIDEND_WIDTH+FRACTION_WIDTH-1'b1:1'b0] q_final;
    reg compare;//com=1;M>N

    assign i_lut_d=o_d_shift[DIVISOR_WIDTH-1'b1:DIVISOR_WIDTH-3'd4];//First 4 decimal places
    assign i_w0=o_x_shift_2;

    reg [DIVIDEND_WIDTH+FRACTION_WIDTH:0] cnt;
    wire cnt_clear;
    reg valid_r;
    assign o_q_valid=valid_r;

    reg [DIVIDEND_WIDTH-1'b1:1'b0] i_x_r;
    reg [DIVISOR_WIDTH-1'b1:1'b0] i_d_r;
    reg [DIVIDEND_WIDTH-1'b1:1'b0] i_x_r2;
    reg [DIVISOR_WIDTH-1'b1:1'b0] i_d_r2;

always@(posedge i_clk or negedge i_rst_n) begin
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
        assign cnt_clear=change1 || change2;

            always @(posedge i_clk or negedge i_rst_n)
            begin
                if(!i_rst_n)begin
                    cnt<=0;
                    valid_r<=1'b0;
                end
                else 
                if(cnt_clear) begin
                    cnt<=0;
                    valid_r<=1'b0;
                end 
                else if(i_clken)begin
                        if(cnt == ((DIVIDEND_WIDTH+FRACTION_WIDTH)/2+4))begin
                            valid_r<=1'b1;
                            cnt<=cnt+1;
                        end 
                        else begin
                            valid_r<=valid_r;
                            cnt<=cnt+1;
                        end
                    end
                    else begin
                        valid_r<=valid_r;
                        cnt<=cnt;
                    end
            end


        preprocess #(
            .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
            .DIVISOR_WIDTH(DIVISOR_WIDTH),
            .FRACTION_WIDTH(FRACTION_WIDTH)
        )  preprocess_u1(
            .i_clk(i_clk)
            ,.i_rst_n(i_rst_n)
            ,.i_clken(i_clken)
            ,.i_x(i_x)
            ,.i_d(i_d)
            ,.o_m(o_m)
            ,.o_n(o_n)
            ,.o_d_shift(o_d_shift)
            ,.o_x_shift(o_x_shift)
        );

        nextpreprocess #(
            .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
            .DIVISOR_WIDTH(DIVISOR_WIDTH),
            .FRACTION_WIDTH(FRACTION_WIDTH)
        )   nextpreprocess_u1(
            .i_d_shift(o_d_shift)
            ,.i_x_shift(o_x_shift)
            ,.o_d_shift_2(o_d_shift_2)
            ,.o_x_shift_2(o_x_shift_2)
            ,.o_max(o_max)
        );

        //shift d right to find value in range [1/2,1)
        //shift x right to find value X<D


        //On-the-Fly Conversion

        srt_awb_clk6x #(
            .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
            .DIVISOR_WIDTH(DIVISOR_WIDTH),
            .FRACTION_WIDTH(FRACTION_WIDTH)
        )   srt_awb_clk6x_0(
            .i_clk(i_clk),
            .i_rst_n(i_rst_n),
            .i_clken(i_clken),
            .i_x(o_x_shift_2),
            .i_w0(i_w0),
            .i_max(o_max),
            .i_lut_d(i_lut_d),
            .i_d(o_d_shift_2),
            .o_output_a(o_output_a),
            .o_output_b(o_output_b),
            .o_output_w(o_output_w),
            .o_d_ready(o_d_ready)
        );

        postprocess #(
            .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
            .DIVISOR_WIDTH(DIVISOR_WIDTH),
            .FRACTION_WIDTH(FRACTION_WIDTH)
        )   postprocess_u1(
            .i_clk(i_clk)
            ,.i_rst_n(i_rst_n)
            ,.i_clken(i_clken)
            ,.i_output_a(o_output_a)
            ,.i_output_b(o_output_b)
            ,.i_output_w(o_output_w)
            ,.i_d_ready(o_d_ready)
            ,.i_m(o_m)
            ,.i_n(o_n)
            ,.i_f(i_f)
            ,.o_q(o_q)
        );
        

endmodule
