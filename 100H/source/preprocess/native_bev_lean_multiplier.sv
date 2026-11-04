// Sequential signed 72 x 72 -> 144 multiplier, timing-split.
// Every carry chain is at most 37 bits: operand negation, the shift-add
// accumulation and the final sign fix-up are each done 36 bits per clock.
// One multiply is in flight at a time; there are no combinational '*' operators.
// Latency: 2 (negate) + 72*2 (add/shift) + 4 (sign fix) + 1 = 151 clocks.
module native_bev_lean_multiplier (
    input  wire                clk,
    input  wire                rst,
    input  wire                start,
    input  wire signed [71:0]  multiplicand,
    input  wire signed [71:0]  multiplier,
    output reg                 busy,
    output reg                 done,
    output reg  signed [143:0] product
);
    wire arithmetic_reset;
    native_bev_reset_branch multiplier_reset_branch (.global_reset(rst),.local_reset(arithmetic_reset));
    localparam S_IDLE=0,S_NEG0=1,S_NEG1=2,S_ADD0=3,S_ADD1=4,S_FIX=5;
    reg [2:0] state;
    reg [71:0] in_a,in_b;          // latched operands
    reg sa,sb,negative;
    reg [71:0] mag_a;              // |multiplicand|
    reg [72:0] hi;                 // running partial product (upper half)
    reg [71:0] lo;                 // multiplier bits, shifted out LSB first
    reg ca,cb,c_add,c_fix;
    reg [35:0] sum_lo;
    reg [6:0] count;
    reg [1:0] fix_k;

    wire [36:0] neg_a_lo = sa ? ({1'b0,~in_a[35:0]}+37'd1) : {1'b0,in_a[35:0]};
    wire [36:0] neg_b_lo = sb ? ({1'b0,~in_b[35:0]}+37'd1) : {1'b0,in_b[35:0]};
    wire [35:0] neg_a_hi = sa ? (~in_a[71:36]+{35'd0,ca}) : in_a[71:36];
    wire [35:0] neg_b_hi = sb ? (~in_b[71:36]+{35'd0,cb}) : in_b[71:36];
    wire [36:0] add_lo = {1'b0,hi[35:0]}+(lo[0]?{1'b0,mag_a[35:0]}:37'd0);
    wire [36:0] add_hi = hi[72:36]+(lo[0]?{1'b0,mag_a[71:36]}:37'd0)+{36'd0,c_add};
    wire [72:0] new_hi = {add_hi,sum_lo};
    wire [143:0] magnitude = {hi[71:0],lo};
    wire [35:0] fix_in = fix_k==0?magnitude[35:0]:fix_k==1?magnitude[71:36]:
                         fix_k==2?magnitude[107:72]:magnitude[143:108];
    wire [36:0] fix_out = {1'b0,(negative?~fix_in:fix_in)}+
                          {36'd0,(fix_k==0?negative:c_fix)};

    // Scratch only: NEG0/NEG1 dominate every hi/lo read; FIX k=0
    // ignores c_fix and writes it before k=1 reads it. These registers may
    // differ during reset/idle, but cannot reach product before those writes.
    // Deliberately no reset gating here: control and public product below
    // retain reset priority, including when reset interrupts S_FIX.
    always @(posedge clk) begin
        case (state)
        S_NEG0: lo[35:0]<=neg_b_lo[35:0];
        S_NEG1: begin
            lo[71:36]<=neg_b_hi;
            hi<=73'd0;
        end
        S_ADD1: begin
            hi<={1'b0,new_hi[72:1]};
            lo<={new_hi[0],lo[71:1]};
        end
        S_FIX: c_fix<=fix_out[36];
        endcase
    end

    always @(posedge clk) begin
        if (arithmetic_reset) begin
            state<=S_IDLE; busy<=1'b0; done<=1'b0; product<=144'sd0;
            in_a<=0; in_b<=0; sa<=0; sb<=0; negative<=0; mag_a<=0;
            ca<=0; cb<=0; c_add<=0; sum_lo<=0; count<=0; fix_k<=0;
        end else begin
            done<=1'b0;
            case (state)
            S_IDLE: if (start) begin
                busy<=1'b1; in_a<=multiplicand; in_b<=multiplier;
                sa<=multiplicand[71]; sb<=multiplier[71];
                negative<=multiplicand[71]^multiplier[71];
                state<=S_NEG0;
            end
            S_NEG0: begin
                mag_a[35:0]<=neg_a_lo[35:0]; ca<=neg_a_lo[36];
                cb<=neg_b_lo[36];
                state<=S_NEG1;
            end
            S_NEG1: begin
                mag_a[71:36]<=neg_a_hi;
                count<=7'd0; state<=S_ADD0;
            end
            S_ADD0: begin
                sum_lo<=add_lo[35:0]; c_add<=add_lo[36]; state<=S_ADD1;
            end
            S_ADD1: begin
                if (count==7'd71) begin fix_k<=0; state<=S_FIX; end
                else begin count<=count+7'd1; state<=S_ADD0; end
            end
            S_FIX: begin
                case (fix_k)
                2'd0: product[35:0]<=fix_out[35:0];
                2'd1: product[71:36]<=fix_out[35:0];
                2'd2: product[107:72]<=fix_out[35:0];
                default: product[143:108]<=fix_out[35:0];
                endcase
                if (fix_k==2'd3) begin busy<=1'b0; done<=1'b1; state<=S_IDLE; end
                else fix_k<=fix_k+2'd1;
            end
            default: state<=S_IDLE;
            endcase
        end
    end
endmodule
