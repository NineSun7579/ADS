
// divider process
//latency:DIVI_ADDQ_W+1(in this module)
module ipsxe_divider_radix2_remainder_v1_0
(
    clk,
    rst_n,
    clk_en,
    cnt,
    dividend,
    divisor,
    remainder,
    quotient,
    divisor_fract
   );
   
parameter    DIVIDEND_W=8;
parameter    DIVISOR_W=8;
parameter    CLK_PER_DIVISION = 1;
parameter    CNT_WIDTH = 1;
parameter    SIGNED = 0;
// Calculate the number of iterations needed for division based on the width of the dividend + quotient and the number of clock cycles per division
localparam   DIVI_ITR = (DIVIDEND_W <= (CLK_PER_DIVISION))?1:(DIVIDEND_W>((DIVIDEND_W>>($clog2(CLK_PER_DIVISION)))*CLK_PER_DIVISION))?
    ((DIVIDEND_W>>$clog2(CLK_PER_DIVISION))+1):(DIVIDEND_W>>($clog2(CLK_PER_DIVISION)));
// Width of dividend and quotient per iteration
localparam   DIVIDEND_ITR = ( DIVIDEND_W + DIVISOR_W + 1 ) * DIVI_ITR + 1;
localparam   ITR_W =  DIVIDEND_W + DIVISOR_W ;
// Width of dividend for each iteration
localparam   DIVISOR_ITR = DIVISOR_W * DIVI_ITR;
// Flag to determine if there are multiple iterations (when CLK_PER_DIVISION is not 1)
//localparam   ITERATION_WIDTH = Remainder_Type ? QUOTIENT_FRACT_W + DIVIDEND_W : DIVIDEND_W;

input        clk;
input        rst_n;
input        clk_en;
input        [CNT_WIDTH:0]cnt;
input        [DIVIDEND_W-1:0] dividend;
input        [DIVISOR_W-1:0] divisor;

output   wire    [DIVISOR_W-1:0]remainder;
output   wire    [DIVIDEND_W-1:0]quotient;
output   wire    [DIVISOR_W-1:0]divisor_fract;

wire   [DIVIDEND_W + DIVISOR_W :0] dividend_2n; //2 sign bit
wire   [DIVIDEND_W + DIVISOR_W + 1:0] divisor_2n; //2 sign bit
wire   [(DIVIDEND_ITR-1):0] dividend_itr;

reg    [(DIVIDEND_ITR-1):0] dividend_itr_r ={(DIVIDEND_ITR-1){1'b0}};
reg    [(DIVISOR_ITR-1):0] divisor_itr_r = {(DIVISOR_ITR-1){1'b0}};

wire   [DIVISOR_W:0] remainder_temp;
//wire   [DIVIDEND_W-1:0] quotient_temp;

wire   [(DIVIDEND_ITR-2):0]dividend_itr_cpd;
wire   [DIVISOR_ITR-1:0]divisor_itr_cpd;

// Generate block to control the assignment of the dividend based on the Remainder_Type
        // If Remainder_Type is not 1, the dividend is not shifted
assign dividend_2n = {{(1 + DIVISOR_W){1'b0}},dividend}; 

// Shift divisor left by DIVI_ADDQ_W bits
//generate if (SIGNED == 1)begin
assign divisor_2n = {{(2){1'b0}},divisor,{DIVIDEND_W{1'b0}}};  
//end
//else begin
//assign divisor_2n = {{1'b0},divisor,{(DIVIDEND_W+1){1'b0}}}; 
//end
//endgenerate

assign divisor_fract = divisor_itr_r[DIVISOR_ITR-1:DIVISOR_ITR-DIVISOR_W];
// Generate block to control the iteration process depending on whether SIGNED is 1 or not
always @(posedge clk or negedge rst_n)
    if(!rst_n)begin
        dividend_itr_r <= {DIVIDEND_ITR {1'b0}};
    end
    else if(clk_en) begin
        dividend_itr_r <= dividend_itr;
    end

// Always block to control the divisor iteration register
always@(posedge clk or negedge rst_n)
    if(!rst_n)begin
        divisor_itr_r <= {DIVISOR_ITR {1'b0}};
    end
    else if (clk_en) begin
        if (cnt == 0) begin
            if (DIVI_ITR==1) begin
                divisor_itr_r <= divisor;
            end
            else begin
                divisor_itr_r[DIVISOR_ITR-1 : DIVISOR_W] <=
                divisor_itr_r[(DIVISOR_ITR-1 - DIVISOR_W):0];
                divisor_itr_r[DIVISOR_W-1:0] <= divisor;
            end
        end
        else begin
            divisor_itr_r <= divisor_itr_r;
        end
    end
    else begin
    end

    
generate
    if (CLK_PER_DIVISION == 1) begin // If the number of clock cycles per division is one, start the iteration block
        genvar i;
        // Unroll the iteration for DIVI_ADDQ_W times using generate for loop
        for(i=0;i<DIVIDEND_W;i=i+1) begin: iteration_n
            if(i==0)begin
                // For the first iteration, use the initial dividend and divisor inputs
                ipsxe_divider_iteration_auto_v1_0 #(.DIVI_ADDQ_W(ITR_W), .DIVISOR_W(DIVISOR_W)) u_ipsxe_divider_iteration_auto_v1_0(
                                               .dividend_2n(dividend_2n),
                                               .divisor_2n(divisor_2n),
                                               .dividend_2n_final(dividend_itr[ITR_W:0]),
                                               .dividend_2n_sign());
            end
            else begin
                // For all other iterations, use the outputs from previous iterations
                if(i==(DIVIDEND_W-1))begin
                    // For the last iteration, also account for the sign of the dividend
                    ipsxe_divider_iteration_auto_v1_0 #(.DIVI_ADDQ_W(ITR_W), .DIVISOR_W(DIVISOR_W)) u_ipsxe_divider_iteration_auto_v1_0(
                                                   .dividend_2n(dividend_itr_r[i*(ITR_W+1)-1:(i-1)*(ITR_W+1)]),
                                                   .divisor_2n({{(2){1'b0}},divisor_itr_r[i*DIVISOR_W-1:(i-1)*DIVISOR_W],{DIVIDEND_W{1'b0}}}),
//                                                   .divisor_2n({{(2){1'b0}},divisor_itr_r[(i+1)*DIVISOR_W-1:i*DIVISOR_W],{DIVIDEND_W{1'b0}}}),

                                                   .dividend_2n_final(dividend_itr[(i+1)*(ITR_W+1)-1:i*(ITR_W+1)]),
                                                   .dividend_2n_sign(dividend_itr[DIVIDEND_ITR-1]));
                end
                else begin
                    ipsxe_divider_iteration_auto_v1_0 #(.DIVI_ADDQ_W(ITR_W), .DIVISOR_W(DIVISOR_W)) u_ipsxe_divider_iteration_auto_v1_0(
                                                   .dividend_2n(dividend_itr_r[i*(ITR_W+1)-1:(i-1)*(ITR_W+1)]),
                                                   .divisor_2n({{(2){1'b0}},divisor_itr_r[i*DIVISOR_W-1:(i-1)*DIVISOR_W],{DIVIDEND_W{1'b0}}}),
//                                                   .divisor_2n({{(2){1'b0}},divisor_itr_r[(i+1)*DIVISOR_W-1:i*DIVISOR_W],{DIVIDEND_W{1'b0}}}),

                                                   .dividend_2n_final(dividend_itr[(i+1)*(ITR_W+1)-1:i*(ITR_W+1)]),
                                                   .dividend_2n_sign());
                end
            end
        end
    end
//when CLK_PER_DIVISION is not equal to one, it handles the calculation differently than when CLK_PER_DIVISION is equal to one. 
//Initially, the dividend_itr_cpd and divisor_itr_cpd variables are assigned with dividend_2n and divisor_2n respectively. 
//Afterwards, a generate loop is unrolled for DIVI_ITR_CPD times to carry out the iterations. For each iteration, 
//the iteration module is invoked with different sections of dividend_itr_cpd and divisor_itr_cpd as inputs based on the counter value.
// For the last iteration, the sign of the dividend_itr is also considered.
    else begin //iteration: clk per division not equal to 1
        assign  dividend_itr_cpd[ITR_W:0] = (cnt == 0)?dividend_2n:dividend_itr_r[ITR_W:0];
        assign  divisor_itr_cpd[DIVISOR_W-1:0] = (cnt == 0)?divisor:divisor_itr_r[DIVISOR_W-1:0] ;
        genvar i;
            for(i=0;i<DIVI_ITR;i=i+1) begin: iteration_n
                if(i==0)begin
                    ipsxe_divider_iteration_auto_v1_0 #(.DIVI_ADDQ_W(ITR_W), .DIVISOR_W(DIVISOR_W)) u_ipsxe_divider_iteration_auto_v1_0(
                                                   .dividend_2n(dividend_itr_cpd[ITR_W:0]),
                                                   .divisor_2n ({{(2){1'b0}},divisor_itr_cpd[DIVISOR_W-1:0],{DIVIDEND_W{1'b0}}}),
                                                   .dividend_2n_final(dividend_itr[ITR_W:0]),
                                                   .dividend_2n_sign());
                end
                else begin
                    if(i==(DIVI_ITR-1))begin
                        assign  dividend_itr_cpd[(i+1)*(ITR_W+1)-1:i*(ITR_W+1)] = (cnt == 0)?
                            dividend_itr_r[i*(ITR_W+1)-1:(i-1)*(ITR_W+1)]:
                            dividend_itr_r[(i+1)*(ITR_W+1)-1:i*(ITR_W+1)];
                        assign  divisor_itr_cpd[(i+1)*DIVISOR_W-1:i*DIVISOR_W] = (cnt == 0)?
                            divisor_itr_r[i*DIVISOR_W-1:(i-1)*DIVISOR_W]:
                            divisor_itr_r[(i+1)*DIVISOR_W-1:i*DIVISOR_W];
                        ipsxe_divider_iteration_auto_v1_0#(.DIVI_ADDQ_W(ITR_W) , .DIVISOR_W(DIVISOR_W)) u_ipsxe_divider_iteration_auto_v1_0(
                            .dividend_2n(dividend_itr_cpd[(i+1)*(ITR_W+1)-1:i*(ITR_W+1)]),
                            .divisor_2n({{(2){1'b0}},divisor_itr_cpd[(i+1)*DIVISOR_W-1:i*DIVISOR_W],{DIVIDEND_W{1'b0}}}),
                            .dividend_2n_final(dividend_itr[(i+1)*(ITR_W+1)-1:i*(ITR_W+1)]),
                            .dividend_2n_sign(dividend_itr[DIVIDEND_ITR-1]));
                    end
                    else begin
                        assign  dividend_itr_cpd[(i+1)*(ITR_W+1)-1:i*(ITR_W+1)] = (cnt == 0)?
                            dividend_itr_r[i*(ITR_W+1)-1:(i-1)*(ITR_W+1)]:
                            dividend_itr_r[(i+1)*(ITR_W+1)-1:i*(ITR_W+1)];
                        assign  divisor_itr_cpd[(i+1)*DIVISOR_W-1:i*DIVISOR_W] = (cnt == 0)?
                            divisor_itr_r[i*DIVISOR_W-1:(i-1)*DIVISOR_W]:
                            divisor_itr_r[(i+1)*DIVISOR_W-1:i*DIVISOR_W];
                        ipsxe_divider_iteration_auto_v1_0 #(.DIVI_ADDQ_W(ITR_W), .DIVISOR_W(DIVISOR_W)) u_ipsxe_divider_iteration_auto_v1_0(
                            .dividend_2n(dividend_itr_cpd[(i+1)*(ITR_W+1)-1:i*(ITR_W+1)]),
                            .divisor_2n({{(2){1'b0}},divisor_itr_cpd[(i+1)*DIVISOR_W-1:i*DIVISOR_W],{DIVIDEND_W{1'b0}}}),
                            .dividend_2n_final(dividend_itr[(i+1)*(ITR_W+1)-1:i*(ITR_W+1)]),
                            .dividend_2n_sign());
                    end
                end
            end
    end
endgenerate
//In this code, based on the condition Remainder_Type == 0, the remainder is calculated in two ways: 
//if the most significant bit of the dividend is 1, the remainder is updated by adding a portion of the dividend and divisor together;
//otherwise, the remainder is set to be a portion of the dividend with a leading zero. 
//The quotient is calculated outside of the generate block by selecting a portion of the dividend.
assign remainder_temp = (dividend_itr_r[DIVIDEND_ITR-1]) ?
                        dividend_itr_r[DIVIDEND_ITR-3:DIVIDEND_ITR-DIVISOR_W-2]+divisor_itr_r[DIVISOR_ITR-1:DIVISOR_ITR-DIVISOR_W] :
                        {1'b0,dividend_itr_r[DIVIDEND_ITR-3:DIVIDEND_ITR-DIVISOR_W-2]};
                        
//   wire [DIVISOR_W:0]m = divisor_itr_r[DIVISOR_ITR-1]? ~divisor_itr_r[DIVISOR_ITR-1:DIVISOR_ITR-DIVISOR_W]+1 : divisor_itr_r[DIVISOR_ITR-1:DIVISOR_ITR-DIVISOR_W];
      wire [DIVISOR_W+2:0]x = dividend_itr_r[DIVIDEND_ITR-3:DIVIDEND_ITR-DIVISOR_W-2];
         wire [DIVISOR_W:0]d = divisor_itr_r[DIVISOR_ITR-1:DIVISOR_ITR-DIVISOR_W];
         wire sign = dividend_itr_r[DIVIDEND_ITR-1];
//    wire     [DIVISOR_W:0]test =    (dividend_itr_r[DIVIDEND_ITR-1]) ?
//                        {dividend_itr_r[DIVIDEND_ITR-1:DIVIDEND_ITR-DIVISOR_W],1'b0}+m :
//                        {2'b00,dividend_itr_r[DIVIDEND_ITR-3:DIVIDEND_ITR-DIVISOR_W-2]};     
                        
//                        wire  [DIVIDEND_W-1:0]q = dividend_itr_r[(DIVIDEND_ITR-DIVISOR_W-3):(DIVIDEND_ITR-ITR_W-2)];           

assign remainder = remainder_temp[DIVISOR_W-1:0];

assign quotient = (|divisor_itr_r[DIVISOR_ITR-1:DIVISOR_ITR-DIVISOR_W]==0) ? {DIVISOR_W{1'b0}} : dividend_itr_r[(DIVIDEND_ITR-DIVISOR_W-3):(DIVIDEND_ITR-ITR_W-2)];

//based on the value of Remainder_Type, determine how the values for quotient_temp, quotient_fract_temp, and remainder_temp are assigned . 
//If Remainder_Type is 1, the quotient is divided into two parts: an integral part (quotient_temp) and a fractional part (quotient_fract_temp). 
//If Remainder_Type is not 1, the entire quotient is assigned to quotient_temp and the remainder to remainder_temp.



endmodule