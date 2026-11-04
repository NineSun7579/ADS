// Sequential signed restoring divider, 144-bit numerator / 72-bit denominator,
// timing-split. The quotient is truncated toward zero; the remainder takes the
// numerator's sign. Divide-by-zero finishes with div_zero.
// Every carry/borrow chain is at most 37 bits: operand negation, each trial
// subtraction and the result sign fix-up are done in 36/37-bit slices.
// Latency: 4 (negate) + 144*2 (trial subtract) + 6 (sign fix) + 1 clocks.
module native_bev_lean_divider (
    input  wire                clk,
    input  wire                rst,
    input  wire                start,
    input  wire signed [143:0] numerator,
    input  wire signed [71:0]  denominator,
    output reg                 busy,
    output reg                 done,
    output reg  signed [143:0] quotient,
    output reg  signed [71:0]  remainder,
    output reg                 div_zero
);
    wire arithmetic_reset;
    native_bev_reset_branch divider_reset_branch (.global_reset(rst),.local_reset(arithmetic_reset));
    localparam S_IDLE=0,S_NEG=1,S_SUB0=2,S_SUB1=3,S_FIX=4;
    reg [2:0] state;
    reg [143:0] in_n;
    reg [71:0] in_d;
    reg sn,sd,neg_q,neg_r;
    reg [143:0] dividend;          // |numerator|, shifted out MSB first
    reg [72:0] divisor;            // {0,|denominator|}
    reg [72:0] partial;
    reg [143:0] quotient_work;
    reg [2:0] k;                   // slice index for negate / fix-up
    reg c;                         // slice carry
    reg [36:0] diff_lo;
    reg borrow_lo;
    reg [7:0] count;

    // Restoring division shifts the next dividend bit into the remainder
    // BEFORE the trial subtraction.
    wire [72:0] shifted = {partial[71:0],dividend[143]};
    wire [37:0] sub_lo = {1'b0,shifted[36:0]}-{1'b0,divisor[36:0]};
    wire [36:0] sub_hi = {1'b0,shifted[72:37]}-{1'b0,divisor[72:37]}-{36'd0,borrow_lo};
    wire no_borrow = !sub_hi[36];
    wire [72:0] next_partial = no_borrow ? {sub_hi[35:0],diff_lo} : shifted;

    // Slice-wise conditional two's complement: slices 0..3 of the numerator
    // (or quotient), slices 4..5 of the denominator (or remainder).
    wire [35:0] neg_in = k==0?in_n[35:0]:k==1?in_n[71:36]:k==2?in_n[107:72]:
                         k==3?in_n[143:108]:k==4?in_d[35:0]:in_d[71:36];
    wire neg_en = k<=3 ? sn : sd;
    wire [36:0] neg_out = {1'b0,(neg_en?~neg_in:neg_in)}+{36'd0,((k==0||k==4)?neg_en:c)};
    wire [35:0] fix_in = k==0?quotient_work[35:0]:k==1?quotient_work[71:36]:
                         k==2?quotient_work[107:72]:k==3?quotient_work[143:108]:
                         k==4?partial[35:0]:partial[71:36];
    wire fix_en = k<=3 ? neg_q : neg_r;
    wire [36:0] fix_out = {1'b0,(fix_en?~fix_in:fix_in)}+{36'd0,((k==0||k==4)?fix_en:c)};

    // Scratch only: S_NEG/k=5 overwrites every bit before S_SUB1 or S_FIX
    // can read it. Reset aborts to S_IDLE. Deliberately ungated by reset: an
    // interrupted operation may update scratch on the reset edge, unobservably.
    // Zero-denominator starts bypass scratch and clear the public results.
    always @(posedge clk) begin
        if (state==S_NEG && k==3'd5) quotient_work<=144'd0;
        else if (state==S_SUB1) quotient_work<={quotient_work[142:0],no_borrow};
    end

    always @(posedge clk) begin
        if (arithmetic_reset) begin
            state<=S_IDLE; busy<=1'b0; done<=1'b0; div_zero<=1'b0;
            quotient<=144'sd0; remainder<=72'sd0;
            in_n<=0; in_d<=0; sn<=0; sd<=0; neg_q<=0; neg_r<=0;
            dividend<=0; divisor<=0; partial<=0;
            k<=0; c<=0; diff_lo<=0; borrow_lo<=0; count<=0;
        end else begin
            done<=1'b0;
            case (state)
            S_IDLE: if (start) begin
                div_zero<=1'b0;
                if (denominator==0) begin
                    quotient<=144'sd0; remainder<=72'sd0;
                    div_zero<=1'b1; done<=1'b1;
                end else begin
                    busy<=1'b1; in_n<=numerator; in_d<=denominator;
                    sn<=numerator[143]; sd<=denominator[71];
                    neg_q<=numerator[143]^denominator[71];
                    neg_r<=numerator[143];
                    k<=3'd0; state<=S_NEG;
                end
            end
            S_NEG: begin
                case (k)
                3'd0: dividend[35:0]<=neg_out[35:0];
                3'd1: dividend[71:36]<=neg_out[35:0];
                3'd2: dividend[107:72]<=neg_out[35:0];
                3'd3: dividend[143:108]<=neg_out[35:0];
                3'd4: divisor[35:0]<=neg_out[35:0];
                default: divisor[72:36]<={1'b0,neg_out[35:0]};
                endcase
                c<=neg_out[36];
                if (k==3'd5) begin
                    partial<=73'd0; count<=8'd0; state<=S_SUB0;
                end else k<=k+3'd1;
            end
            S_SUB0: begin
                diff_lo<=sub_lo[36:0]; borrow_lo<=sub_lo[37]; state<=S_SUB1;
            end
            S_SUB1: begin
                partial<=next_partial;
                dividend<=dividend<<1;
                if (count==8'd143) begin k<=3'd0; state<=S_FIX; end
                else begin count<=count+8'd1; state<=S_SUB0; end
            end
            S_FIX: begin
                case (k)
                3'd0: quotient[35:0]<=fix_out[35:0];
                3'd1: quotient[71:36]<=fix_out[35:0];
                3'd2: quotient[107:72]<=fix_out[35:0];
                3'd3: quotient[143:108]<=fix_out[35:0];
                3'd4: remainder[35:0]<=fix_out[35:0];
                default: remainder[71:36]<=fix_out[35:0];
                endcase
                c<=fix_out[36];
                if (k==3'd5) begin busy<=1'b0; done<=1'b1; state<=S_IDLE; end
                else k<=k+3'd1;
            end
            default: state<=S_IDLE;
            endcase
        end
    end
endmodule
