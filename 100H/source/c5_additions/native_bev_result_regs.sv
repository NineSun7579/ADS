// Native BEV lane result page, 0x20021200..0x200213f0 (16-byte registers).
// Schema 2: the last completed half publishes BOTH lanes (left/right curve and
// solid/dashed statistics). Curve model for each lane:
//   col_q4 = a*u^2 + b*u + c   (Q8 coefficients, u = bird_row - 104, rows 0..207)
//   bird column = 125 + col_q4/4096
// 0x80..0xa0 keep the stronger lane's coefficients for older readers.
// The host sees a stable snapshot with a result sequence and a separate
// current sequence counter. No software BEV computation is involved.
module native_bev_result_regs(
    input wire clk,input wire rst,
    input wire [8:0] address,      // read address (held by the page router)
    input wire [8:0] waddr,        // write address
    input wire [31:0] wdata,input wire write_enable,
    output reg [31:0] control,
    input wire [31:0] status,
    input wire [31:0] result_generation,input wire [31:0] result_sequence,
    input wire [15:0] result_valid,input wire [15:0] result_half,
    input wire [15:0] result_candidates,input wire [15:0] result_strength,
    input wire signed [31:0] result_a,input wire signed [31:0] result_b,input wire signed [31:0] result_c,
    input wire [31:0] result_dash_left,input wire [31:0] result_dash_right,
    input wire signed [31:0] result_left_a,input wire signed [31:0] result_left_b,input wire signed [31:0] result_left_c,
    input wire signed [31:0] result_right_a,input wire signed [31:0] result_right_b,input wire signed [31:0] result_right_c,
    input wire [15:0] result_left_n,input wire [15:0] result_left_strength,
    input wire [15:0] result_right_n,input wire [15:0] result_right_strength,
    input wire [31:0] debug_count,input wire [31:0] debug_state,
    output reg [31:0] rdata
);
    reg [31:0] accept_sequence;
    always @(posedge clk) begin
        if(rst) begin control<=1;accept_sequence<=0;end
        else begin
            if(write_enable && waddr==9'h010) control<=wdata;
            if(status[0]) accept_sequence<=result_sequence;
        end
    end
    // rdata is registered: the router holds the read address from AR accept
    // until R completes, and R is returned at least one clock after AR, so a
    // registered copy is always current when it is sampled.
    always @(posedge clk) begin
        case(address)
            9'h000:rdata<=32'h4e424c32; // NBL2, native BEV lane page
            9'h010:rdata<=control;
            9'h020:rdata<=status;
            9'h030:rdata<=result_generation;
            9'h040:rdata<=result_sequence;
            9'h050:rdata<=accept_sequence;
            9'h060:rdata<={result_half,result_valid};
            9'h070:rdata<={result_strength,result_candidates};
            9'h080:rdata<=result_a;
            9'h090:rdata<=result_b;
            9'h0a0:rdata<=result_c;
            9'h0b0:rdata<={16'd2,16'd8}; // schema=2, Q fractional bits=8
            9'h0c0:rdata<=debug_count;
            9'h0d0:rdata<=debug_state;
            9'h0e0:rdata<={16'd480,16'd360};
            9'h0f0:rdata<={16'd80,16'd600};
            // dash word: bit0 line seen, bit1 solid, [10:2] present rows,
            // [19:11] span rows, [28:20] longest gap
            9'h100:rdata<=result_dash_left;
            9'h110:rdata<=result_dash_right;
            9'h120:rdata<=result_left_a;
            9'h130:rdata<=result_left_b;
            9'h140:rdata<=result_left_c;
            9'h150:rdata<=result_right_a;
            9'h160:rdata<=result_right_b;
            9'h170:rdata<=result_right_c;
            9'h180:rdata<={result_left_strength,result_left_n};
            9'h190:rdata<={result_right_strength,result_right_n};
            default:rdata<=0;
        endcase
    end
endmodule
