// Walks a fitted lane curve col = 125 + (a*u^2 + b*u + c)/4096 (u = row-104,
// Q8 coefficients on Q4 columns) over the stored ridge mask, top row first.
// The curve is produced on the fly by forward differences from u=-104 using
// shifts and adds only (no multiplier, no per-row prediction array).
// For every mask row 0..207 it emits one event: the hit nearest to the curve
// within +-tol columns (hit, col) or a miss. The consumer pulses ev_ack to
// continue. Only mask columns 20..229 are ever valid.
module native_bev_lean_walker (
    input  wire clk, input  wire rst,
    input  wire start,
    input  wire signed [31:0] a, b, c,
    input  wire [3:0] tol,
    output reg  [15:0] mask_addr,
    input  wire mask_bit,                 // registered, one cycle after mask_addr
    output reg  ev_valid,
    output reg  [7:0] ev_row,
    output reg  ev_hit,
    output reg  [7:0] ev_col,
    input  wire ev_ack,
    output reg  busy, output reg done
);
    localparam S_IDLE=0,S_INIT=1,S_ROW=2,S_ADDR=3,S_WAIT=4,S_DATA=5,S_EMIT=6;
    reg [2:0] state;
    reg signed [39:0] p, d, a2;
    reg [7:0] row;
    reg [3:0] kmag; reg kneg;           // offset order 0,+1,-1,+2,-2,...
    reg signed [10:0] pc;
    reg [15:0] row_base;
    reg cvalid;
    reg signed [39:0] sa, sb, sc;
    wire signed [39:0] rounded = (p + 40'sd2048) >>> 12;
    wire signed [11:0] col_raw = 12'sd125 + rounded[11:0];
    wire [7:0] col_clamped = col_raw < 0 ? 8'd0 : col_raw > 249 ? 8'd249 : col_raw[7:0];
    wire signed [10:0] k_signed = kneg ? -$signed({7'd0,kmag}) : $signed({7'd0,kmag});
    wire signed [10:0] cand_now = pc + k_signed;
    wire cand_ok = cand_now >= 20 && cand_now <= 229;
    // p(-104) = 10816a - 104b + c ; d(-104) = p(-103)-p(-104) = -207a + b
    wire signed [39:0] p0 = (sa<<<13)+(sa<<<11)+(sa<<<9)+(sa<<<6)-((sb<<<6)+(sb<<<5)+(sb<<<3))+sc;
    wire signed [39:0] d0 = sb-((sa<<<7)+(sa<<<6)+(sa<<<3)+(sa<<<2)+(sa<<<1)+sa);
    always @(posedge clk) begin
        if (rst) begin
            state<=S_IDLE; busy<=0; done<=0; ev_valid<=0; ev_hit<=0; ev_row<=0;
            ev_col<=0; mask_addr<=0; p<=0; d<=0; a2<=0; row<=0; kmag<=0; kneg<=0;
            pc<=0; row_base<=0; cvalid<=0; sa<=0; sb<=0; sc<=0;
        end else begin
            done<=0;
            case (state)
            S_IDLE: if (start) begin
                busy<=1; sa<={{8{a[31]}},a}; sb<={{8{b[31]}},b}; sc<={{8{c[31]}},c};
                state<=S_INIT;
            end
            S_INIT: begin
                p<=p0; d<=d0; a2<=sa<<<1; row<=0; row_base<=0; state<=S_ROW;
            end
            S_ROW: begin
                pc<={3'b000,col_clamped}; kmag<=0; kneg<=0; state<=S_ADDR;
            end
            S_ADDR: begin
                mask_addr<=row_base+{5'd0,cand_now[10:0]};
                cvalid<=cand_ok; state<=S_WAIT;
            end
            S_WAIT: state<=S_DATA;
            S_DATA: begin
                if (cvalid && mask_bit) begin
                    ev_hit<=1; ev_col<=cand_now[7:0]; ev_row<=row; ev_valid<=1; state<=S_EMIT;
                end else if (kmag==tol && kneg) begin
                    ev_hit<=0; ev_row<=row; ev_valid<=1; state<=S_EMIT;
                end else begin
                    if (kmag==0) begin kmag<=4'd1; kneg<=0; end
                    else if (!kneg) kneg<=1;
                    else begin kneg<=0; kmag<=kmag+4'd1; end
                    state<=S_ADDR;
                end
            end
            S_EMIT: if (ev_ack) begin
                ev_valid<=0;
                if (row==8'd207) begin busy<=0; done<=1; state<=S_IDLE; end
                else begin
                    row<=row+8'd1; row_base<=row_base+16'd250;
                    p<=p+d; d<=d+a2; state<=S_ROW;
                end
            end
            default: state<=S_IDLE;
            endcase
        end
    end
endmodule
