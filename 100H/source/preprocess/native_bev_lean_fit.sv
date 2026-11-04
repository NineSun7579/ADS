// Synthesizable least-squares parabola fit: v = a*u*u + b*u + c.
// u is an integer bird-column offset and v is lateral decimetres.
// Fraction-free Bareiss Gaussian elimination preserves exact integer pivots.
// Q8 scaling is applied only during back-substitution, avoiding loss of small
// curvature values. All nonlinear arithmetic uses the two iterative units.
module native_bev_lean_fit #(parameter MIN_N=4, MIN_COVER=60) (
    input  wire                clk,
    input  wire                rst,
    input  wire                start,
    input  wire        [15:0]  n,
    input  wire signed [39:0]  su,
    input  wire signed [39:0]  su2,
    input  wire signed [39:0]  su3,
    input  wire signed [39:0]  su4,
    input  wire signed [39:0]  sv,
    input  wire signed [39:0]  suv,
    input  wire signed [39:0]  su2v,
    input  wire        [7:0]   u_min,
    input  wire        [7:0]   u_max,
    output reg                 busy,
    output reg                 done,
    output reg                 valid,
    output reg signed  [31:0]  a_q8,
    output reg signed  [31:0]  b_q8,
    output reg signed  [31:0]  c_q8,
    output reg         [31:0]  debug_pivot,
    output reg         [3:0]   debug_stage
);
    wire fit_reset;
    native_bev_reset_branch fit_reset_branch (.global_reset(rst),.local_reset(fit_reset));
    reg signed [71:0] m00,m01,m02,m03;
    reg signed [71:0] m10,m11,m12,m13;
    reg signed [71:0] m20,m21,m22,m23;
    reg signed [71:0] previous_pivot;
    reg signed [143:0] first_product;
    reg signed [143:0] correction;
    reg [1:0] pivot,work_row,work_col;
    reg [4:0] state;
    reg mul_start,div_start,mul_phase,solved;
    reg signed [71:0] mul_a,mul_b,div_denominator;
    reg signed [143:0] div_numerator;
    wire mul_busy,mul_done,div_busy,div_done,div_zero;
    wire signed [143:0] mul_product,div_quotient;
    wire signed [71:0] div_remainder;

    native_bev_lean_multiplier shared_multiplier (
        .clk(clk),.rst(rst),.start(mul_start),
        .multiplicand(mul_a),.multiplier(mul_b),
        .busy(mul_busy),.done(mul_done),.product(mul_product)
    );
    native_bev_lean_divider shared_divider (
        .clk(clk),.rst(rst),.start(div_start),
        .numerator(div_numerator),.denominator(div_denominator),
        .busy(div_busy),.done(div_done),.quotient(div_quotient),
        .remainder(div_remainder),.div_zero(div_zero)
    );

    localparam S_IDLE=0,S_CHECK=1,S_PRODUCT_START=2,S_PRODUCT_WAIT=3,
               S_DIV_START=4,S_DIV_WAIT=5,S_A_DIV=6,S_A_WAIT=7,
               S_B_MUL=8,S_B_WAIT=9,S_B_DIV=10,S_B_DIV_WAIT=11,
               S_C_MUL1=12,S_C_WAIT1=13,S_C_MUL2=14,S_C_WAIT2=15,
               S_C_DIV=16,S_C_WAIT=17,S_FINISH=18,S_CHECK2=19;

    function signed [71:0] element;
        input [1:0] row;
        input [1:0] col;
        begin
            case ({row,col})
                4'h0:element=m00; 4'h1:element=m01;
                4'h2:element=m02; 4'h3:element=m03;
                4'h4:element=m10; 4'h5:element=m11;
                4'h6:element=m12; 4'h7:element=m13;
                4'h8:element=m20; 4'h9:element=m21;
                4'ha:element=m22; default:element=m23;
            endcase
        end
    endfunction
    task put_element;
        input [1:0] row;
        input [1:0] col;
        input signed [71:0] value;
        begin
            case ({row,col})
                4'h0:m00<=value; 4'h1:m01<=value;
                4'h2:m02<=value; 4'h3:m03<=value;
                4'h4:m10<=value; 4'h5:m11<=value;
                4'h6:m12<=value; 4'h7:m13<=value;
                4'h8:m20<=value; 4'h9:m21<=value;
                4'ha:m22<=value; 4'hb:m23<=value;
                default: begin end
            endcase
        end
    endtask

    reg signed [71:0] pivot_magnitude;   // raw pivot element (debug + zero test)
    reg pivot_zero;
    always @(posedge clk) begin
        if (fit_reset) begin
            busy<=0;done<=0;valid<=0;a_q8<=0;b_q8<=0;c_q8<=0;
            debug_pivot<=0;debug_stage<=0;state<=S_IDLE;
            pivot<=0;work_row<=0;work_col<=0;previous_pivot<=1;
            first_product<=0;correction<=0;
            mul_start<=0;div_start<=0;mul_phase<=0;solved<=0;
            mul_a<=0;mul_b<=0;div_numerator<=0;div_denominator<=0;
            m00<=0;m01<=0;m02<=0;m03<=0;m10<=0;m11<=0;m12<=0;m13<=0;
            m20<=0;m21<=0;m22<=0;m23<=0;
        end else begin
            done<=0;mul_start<=0;div_start<=0;debug_stage<=state;
            case(state)
                S_IDLE: if(start) begin
                    busy<=1;valid<=0;a_q8<=0;b_q8<=0;c_q8<=0;solved<=0;
                    debug_pivot<=0;pivot<=0;previous_pivot<=1;
                    m00<=$signed({56'd0,n});m01<=su;m02<=su2;m03<=sv;
                    m10<=su;m11<=su2;m12<=su3;m13<=suv;
                    m20<=su2;m21<=su3;m22<=su4;m23<=su2v;
                    if(n<MIN_N || u_max<u_min || (u_max-u_min)<MIN_COVER)
                        state<=S_FINISH;
                    else state<=S_CHECK;
                end
                // Pivot check is split over two clocks: the element select and the
                // 72-bit zero test are registered before they steer the FSM.
                S_CHECK: begin
                    pivot_magnitude<=element(pivot,pivot);
                    pivot_zero<=(element(pivot,pivot)==0);
                    state<=S_CHECK2;
                end
                S_CHECK2: begin
                    debug_pivot<=pivot_magnitude[31:0];
                    if(pivot_zero) state<=S_FINISH;
                    else if(pivot==2) begin
                        div_numerator<=$signed(m23)<<<8;
                        div_denominator<=m22;
                        state<=S_A_DIV;
                    end else begin
                        work_row<=pivot+1'b1;work_col<=pivot+1'b1;
                        mul_phase<=0;state<=S_PRODUCT_START;
                    end
                end
                S_PRODUCT_START: begin
                    if(!mul_phase) begin
                        mul_a<=element(work_row,work_col);
                        mul_b<=element(pivot,pivot);
                    end else begin
                        mul_a<=element(work_row,pivot);
                        mul_b<=element(pivot,work_col);
                    end
                    mul_start<=1;state<=S_PRODUCT_WAIT;
                end
                S_PRODUCT_WAIT: if(mul_done) begin
                    if(!mul_phase) begin
                        first_product<=mul_product;mul_phase<=1;
                        state<=S_PRODUCT_START;
                    end else begin
                        div_numerator<=first_product-mul_product;
                        div_denominator<=previous_pivot;
                        state<=S_DIV_START;
                    end
                end
                S_DIV_START: begin div_start<=1;state<=S_DIV_WAIT;end
                S_DIV_WAIT: if(div_done) begin
                    if(div_zero) state<=S_FINISH;
                    else begin
                        put_element(work_row,work_col,div_quotient[71:0]);
                        if(work_col==3) begin
                            put_element(work_row,pivot,0);
                            if(work_row==2) begin
                                previous_pivot<=element(pivot,pivot);
                                pivot<=pivot+1'b1;state<=S_CHECK;
                            end else begin
                                work_row<=work_row+1'b1;
                                work_col<=pivot+1'b1;mul_phase<=0;
                                state<=S_PRODUCT_START;
                            end
                        end else begin
                            work_col<=work_col+1'b1;mul_phase<=0;
                            state<=S_PRODUCT_START;
                        end
                    end
                end
                S_A_DIV: begin div_start<=1;state<=S_A_WAIT;end
                S_A_WAIT: if(div_done) begin
                    if(div_zero) state<=S_FINISH;
                    else begin
                        a_q8<=div_quotient[31:0];
                        mul_a<=m12;mul_b<={{40{div_quotient[31]}},div_quotient[31:0]};
                        state<=S_B_MUL;
                    end
                end
                S_B_MUL: begin mul_start<=1;state<=S_B_WAIT;end
                S_B_WAIT: if(mul_done) begin
                    div_numerator<=($signed(m13)<<<8)-mul_product;
                    div_denominator<=m11;state<=S_B_DIV;
                end
                S_B_DIV: begin div_start<=1;state<=S_B_DIV_WAIT;end
                S_B_DIV_WAIT: if(div_done) begin
                    if(div_zero) state<=S_FINISH;
                    else begin
                        b_q8<=div_quotient[31:0];
                        mul_a<=m01;mul_b<={{40{div_quotient[31]}},div_quotient[31:0]};
                        state<=S_C_MUL1;
                    end
                end
                S_C_MUL1: begin mul_start<=1;state<=S_C_WAIT1;end
                S_C_WAIT1: if(mul_done) begin
                    correction<=mul_product;mul_a<=m02;mul_b<={{40{a_q8[31]}},a_q8};
                    state<=S_C_MUL2;
                end
                S_C_MUL2: begin mul_start<=1;state<=S_C_WAIT2;end
                S_C_WAIT2: if(mul_done) begin
                    div_numerator<=($signed(m03)<<<8)-correction-mul_product;
                    div_denominator<=m00;state<=S_C_DIV;
                end
                S_C_DIV: begin div_start<=1;state<=S_C_WAIT;end
                S_C_WAIT: if(div_done) begin
                    if(!div_zero) begin c_q8<=div_quotient[31:0];solved<=1;end
                    state<=S_FINISH;
                end
                S_FINISH: begin
                    if(solved && a_q8>=-128 && a_q8<=128) valid<=1;
                    busy<=0;done<=1;state<=S_IDLE;
                end
                default:state<=S_IDLE;
            endcase
        end
    end
endmodule
