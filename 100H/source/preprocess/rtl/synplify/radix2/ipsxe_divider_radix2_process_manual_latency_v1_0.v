`timescale 1ns / 1ps
// divider process
//latency:DIVI_ADDQ_W+1(in this module)
module ipsxe_divider_radix2_process_manual_latency_v1_0
(
    clk,
    rst_n,
    clk_en,
    dividend,
    divisor,
    quotient_fract_out,
    remainder_out,
    quotient_out
   );
   
parameter    DIVIDEND_W=8;
parameter    DIVISOR_W=8;
parameter    QUOTIENT_FRACT_W=8;
parameter    DIVI_ADDQ_W = 16;
parameter    Remainder_Type = 1;
parameter    MANUAL_LATENCY =16;

localparam   DIVI_ITR_MODE = ((DIVI_ADDQ_W>>1) <= MANUAL_LATENCY) ? 2 : 
                             ((DIVI_ADDQ_W>>2) <= MANUAL_LATENCY) ? 4 :
                             ((DIVI_ADDQ_W>>3) <= MANUAL_LATENCY) ? 8 :
                             ((DIVI_ADDQ_W>>4) <= MANUAL_LATENCY) ? 16: 
                             ((DIVI_ADDQ_W>>5) <= MANUAL_LATENCY) ? 32: 64;
// Calculate the number of iterations needed for division based on the width of the dividend + quotient and the number of clock cycles per division
localparam   DIVI_ITR_CPD =  ((DIVI_ADDQ_W>>1) <= MANUAL_LATENCY) ? (DIVI_ADDQ_W>>1) :
                             ((DIVI_ADDQ_W>>2) <= MANUAL_LATENCY) ? (DIVI_ADDQ_W>>2) : 
                             ((DIVI_ADDQ_W>>3) <= MANUAL_LATENCY) ? (DIVI_ADDQ_W>>3) :
                             ((DIVI_ADDQ_W>>4) <= MANUAL_LATENCY) ? (DIVI_ADDQ_W>>4) :
                             ((DIVI_ADDQ_W>>5) <= MANUAL_LATENCY) ? (DIVI_ADDQ_W>>5) : 
                             ((DIVI_ADDQ_W>>6) <= MANUAL_LATENCY) ? (DIVI_ADDQ_W>>6) :MANUAL_LATENCY;

localparam   ITR_REMAINDER_CPD = DIVIDEND_W>>$clog2(DIVI_ITR_MODE);

localparam   ITR_FRACT_CPD = QUOTIENT_FRACT_W>>$clog2(DIVI_ITR_MODE);

localparam   ITR_REMAINDER_CPD_NOTZERO = ITR_REMAINDER_CPD == 0 ? 1 : ITR_REMAINDER_CPD;

localparam   ITR_FRACT_CPD_NOTZERO = ITR_FRACT_CPD == 0 ? 1 : ITR_FRACT_CPD;

localparam   ITR_REMAINDER_CPD_PIUS1 = ((ITR_REMAINDER_CPD_NOTZERO + ITR_FRACT_CPD_NOTZERO) < MANUAL_LATENCY) & (DIVIDEND_W > DIVI_ITR_MODE * ITR_REMAINDER_CPD_NOTZERO);

// localparam   ITR_FRACT_CPD_PLUS1 = ((ITR_REMAINDER_CPD + ITR_FRACT_CPD + ITR_REMAINDER_CPD_PIUS1) < MANUAL_LATENCY) & (QUOTIENT_FRACT_W > (ITR_FRACT_CPD*DIVI_ITR_MODE));

localparam   DIVI_ITR_REM = DIVI_ADDQ_W - (DIVI_ITR_CPD * DIVI_ITR_MODE);

localparam   DIVI_ITR_PIPE =  (Remainder_Type == 1) ? (MANUAL_LATENCY - ITR_REMAINDER_CPD_NOTZERO - ITR_FRACT_CPD_NOTZERO - ITR_REMAINDER_CPD_PIUS1 ) :
                                                      (MANUAL_LATENCY - DIVI_ITR_CPD);

localparam   DIVI_ITR_REMAINDER_REM = ITR_REMAINDER_CPD == 0 ? 0 : (DIVIDEND_W - (ITR_REMAINDER_CPD * DIVI_ITR_MODE));

localparam   DIVI_ITR_FRACT_REM = ITR_FRACT_CPD == 0 ? 0 : (QUOTIENT_FRACT_W - (ITR_FRACT_CPD * DIVI_ITR_MODE));

localparam   ITR_W =  DIVIDEND_W + DIVISOR_W ;
//  iteration of remainder
localparam   DIVIDEND_ITR = (DIVIDEND_W + DIVISOR_W + 1) * ITR_REMAINDER_CPD_NOTZERO + 1;

localparam   DIVISOR_ITR = DIVISOR_W * ITR_REMAINDER_CPD_NOTZERO;
//  iteration of fraction
localparam   DIVIDEND_FRACT_ITR = (DIVISOR_W + 1) * ITR_FRACT_CPD_NOTZERO;

localparam   DIVISOR_FRACT_ITR = DIVISOR_W * ITR_FRACT_CPD_NOTZERO;

localparam   QUOTIENT_FRACT_ITR = ITR_FRACT_CPD == 0 ? QUOTIENT_FRACT_W : ((1+ITR_FRACT_CPD) * (ITR_FRACT_CPD) * DIVI_ITR_MODE)>>1;

localparam   QUOTIENT_FRACT_INIT = ITR_FRACT_CPD == 0 ? QUOTIENT_FRACT_W : ITR_FRACT_CPD * DIVI_ITR_MODE;

input        clk;
input        rst_n;
input        clk_en;
input        [DIVIDEND_W-1:0] dividend;
input        [DIVISOR_W-1:0] divisor;

  //signed input

output   wire    [QUOTIENT_FRACT_W-1:0]quotient_fract_out;
output   wire    [DIVISOR_W-1:0]remainder_out;
output   wire    [DIVIDEND_W-1:0]quotient_out;

wire   [DIVIDEND_W + DIVISOR_W :0] dividend_2n; //2 sign bit
wire   [DIVIDEND_W + DIVISOR_W + 1:0] divisor_2n; //2 sign bit
wire   [(DIVIDEND_ITR-1):0] dividend_itr;

reg    [(DIVIDEND_ITR-1):0] dividend_itr_r={DIVIDEND_ITR{1'b0}};
reg    [(DIVISOR_ITR-1):0] divisor_itr_r={DIVISOR_ITR{1'b0}};
// wire   [(2*DIVI_ADDQ_W+1):0] dividend_2n; //2 sign bit
// wire   [2*DIVI_ADDQ_W+1:0] divisor_2n; //2 sign bit
// wire   [(DIVI_W_ITR-1):0] dividend_itr;

// reg    [(DIVI_W_ITR-1):0] dividend_itr_r=0;
// reg    [(DIVI_W_ITR-1):0] divisor_itr_r=0;
wire    [DIVISOR_W-1:0]divisor_fract;
wire    [DIVISOR_W:0]remainder_temp;
wire    [DIVIDEND_W-1:0] quotient_temp;
wire    [DIVISOR_W-1:0]remainder;
wire    [DIVIDEND_W-1:0] quotient;
wire    [QUOTIENT_FRACT_W-1:0]fraction;
wire  [DIVIDEND_W-1:0] quotient_fra;
wire   [(DIVIDEND_FRACT_ITR-1):0] dividend_fract_itr; 
wire   [QUOTIENT_FRACT_INIT-1:0] quotient_init;
        //wire   [QUOTIENT_ITR-1:0] quotient_itr;
reg    [(DIVIDEND_FRACT_ITR-1):0] dividend_fract_itr_r={DIVIDEND_FRACT_ITR{1'b0}};
reg    [(DIVISOR_FRACT_ITR-1):0] divisor_fract_itr_r={DIVISOR_FRACT_ITR{1'b0}};  
reg    [QUOTIENT_FRACT_ITR-1:0] quotient_fract_itr_r={QUOTIENT_FRACT_ITR{1'b0}};

// Generate block to control the assignment of the dividend based on the Remainder_Type
assign dividend_2n = {{(1 + DIVISOR_W){1'b0}},dividend}; 

// Shift divisor left by DIVI_ADDQ_W bits
assign divisor_2n = {{(2){1'b0}},divisor,{DIVIDEND_W{1'b0}}};  

//assign divisor_fract = divisor_itr_r[DIVISOR_ITR-1:DIVISOR_ITR-DIVISOR_W];
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
        if (ITR_REMAINDER_CPD <= 1) begin
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
  

    // Unroll the iteration for DIVI_ADDQ_W times using generate for loop
generate
    if(ITR_REMAINDER_CPD==0)begin
        ipsxe_divider_iteration_auto_nx_v1_0 #(.DIVI_ADDQ_W(ITR_W),
                       .DIVI_ITR_REM(DIVIDEND_W), 
                       .DIVISOR_W(DIVISOR_W)
                      ) u_ipsxe_divider_iteration_nx_v1_0(.dividend_2n(dividend_2n),
                       .divisor_2n(divisor_2n),
                       .dividend_2n_final(dividend_itr[ITR_W:0]),
                       .dividend_2n_sign(dividend_itr[DIVIDEND_ITR-1]));
    end
    else begin
        if(ITR_REMAINDER_CPD==1)begin
            ipsxe_divider_iteration_auto_nx_v1_0 #(.DIVI_ADDQ_W(ITR_W),
                           .DIVI_ITR_REM(DIVI_ITR_MODE), 
                           .DIVISOR_W(DIVISOR_W)
                          ) u_ipsxe_divider_iteration_nx_v1_0(.dividend_2n(dividend_2n),
                           .divisor_2n(divisor_2n),
                           .dividend_2n_final(dividend_itr[ITR_W:0]),
                           .dividend_2n_sign(dividend_itr[DIVIDEND_ITR-1]));
        end
        else begin
            genvar i;
            for(i=0;i<ITR_REMAINDER_CPD;i=i+1) begin: iteration_n
                if(i==0)begin
                    // For the first iteration, use the initial dividend and divisor inputs
                    ipsxe_divider_iteration_auto_nx_v1_0 #(.DIVI_ADDQ_W(ITR_W),
                                   .DIVI_ITR_REM(DIVI_ITR_MODE),
                                   .DIVISOR_W(DIVISOR_W)
                                   ) u_ipsxe_divider_iteration_nx_v1_0(.dividend_2n(dividend_2n),
                                   .divisor_2n(divisor_2n),
                                   .dividend_2n_final(dividend_itr[ITR_W:0]),
                                   .dividend_2n_sign());
                end
                else begin
                    // For all other iterations, use the outputs from previous iterations
                    if(i==(ITR_REMAINDER_CPD-1))begin
                        // For the last iteration, also account for the sign of the dividend
                        ipsxe_divider_iteration_auto_nx_v1_0 #(.DIVI_ADDQ_W(ITR_W),
                                       .DIVI_ITR_REM(DIVI_ITR_MODE), 
                                       .DIVISOR_W(DIVISOR_W)
                                       ) u_ipsxe_divider_iteration_nx_v1_0(
                                       .dividend_2n(dividend_itr_r[i*(ITR_W+1)-1:(i-1)*(ITR_W+1)]),
                                       .divisor_2n({{(2){1'b0}},divisor_itr_r[i*DIVISOR_W-1:(i-1)*DIVISOR_W],{DIVIDEND_W{1'b0}}}),
                                       .dividend_2n_final(dividend_itr[(i+1)*(ITR_W+1)-1:i*(ITR_W+1)]),
                                       .dividend_2n_sign(dividend_itr[DIVIDEND_ITR-1]));
                    end
                    else begin
                        ipsxe_divider_iteration_auto_nx_v1_0 #(.DIVI_ADDQ_W(ITR_W),
                                       .DIVI_ITR_REM(DIVI_ITR_MODE), 
                                       .DIVISOR_W(DIVISOR_W)
                                       ) u_ipsxe_divider_iteration_nx_v1_0 (
                                       .dividend_2n(dividend_itr_r[i*(ITR_W+1)-1:(i-1)*(ITR_W+1)]),
                                       .divisor_2n({{(2){1'b0}},divisor_itr_r[i*DIVISOR_W-1:(i-1)*DIVISOR_W],{DIVIDEND_W{1'b0}}}),
                                       .dividend_2n_final(dividend_itr[(i+1)*(ITR_W+1)-1:i*(ITR_W+1)]),
                                       .dividend_2n_sign());
                    end
                end
            end
        end
    end
endgenerate
//In this code, based on the condition Remainder_Type == 0, the remainder is calculated in two ways: 
//if the most significant bit of the dividend is 1, the remainder is updated by adding a portion of the dividend and divisor together;
//otherwise, the remainder is set to be a portion of the dividend with a leading zero. 
//The quotient is calculated outside of the generate block by selecting a portion of the dividend.
generate
    if(DIVI_ITR_REMAINDER_REM==0)begin
        assign remainder_temp = (dividend_itr_r[DIVIDEND_ITR-1]) ?
                                dividend_itr_r[DIVIDEND_ITR-3:DIVIDEND_ITR-DIVISOR_W-2]+divisor_itr_r[DIVISOR_ITR-1:DIVISOR_ITR-DIVISOR_W] :
                                {1'b0,dividend_itr_r[DIVIDEND_ITR-3:DIVIDEND_ITR-DIVISOR_W-2]};
                                
//                                wire [DIVISOR_W-1:0]test0 = divisor_itr_r[DIVISOR_ITR-1:DIVISOR_ITR-DIVISOR_W];
//                                wire [DIVISOR_W+1:0]test1 = dividend_itr_r[DIVIDEND_ITR-1:DIVIDEND_ITR-DIVISOR_W-2];
        assign remainder = remainder_temp[DIVISOR_W-1:0];
        assign quotient = ((|divisor_itr_r[DIVISOR_ITR-1:DIVISOR_ITR-DIVISOR_W])==0) ? {DIVISOR_W{1'b0}} : dividend_itr_r[(DIVIDEND_ITR-DIVISOR_W-3):(DIVIDEND_ITR-ITR_W-2)];
        assign divisor_fract = divisor_itr_r[DIVISOR_ITR-1:DIVISOR_ITR-DIVISOR_W];
    end
    else begin
        wire [ITR_W + 1:0]dividend_rem;
        ipsxe_divider_iteration_auto_nx_v1_0 #(.DIVI_ADDQ_W(ITR_W),
                       .DIVI_ITR_REM(DIVI_ITR_REMAINDER_REM), 
                       .DIVISOR_W(DIVISOR_W)
                      ) u_ipsxe_divider_iteration_nx_v1_0_rem(
                       .dividend_2n(dividend_itr_r[DIVIDEND_ITR-2:DIVIDEND_ITR-ITR_W-2]),
                       .divisor_2n({{(2){1'b0}},divisor_itr_r[DIVISOR_ITR-1:DIVISOR_ITR-DIVISOR_W],{DIVIDEND_W{1'b0}}}),
                       .dividend_2n_final(dividend_rem[ITR_W:0]),
                       .dividend_2n_sign(dividend_rem[ITR_W+1]));
        assign remainder_temp =  (dividend_rem[ITR_W+1]) ? dividend_rem[ITR_W-1:ITR_W-DIVISOR_W]+divisor_itr_r[DIVISOR_ITR-1:DIVISOR_ITR-DIVISOR_W] :
                                {1'b0,dividend_rem[ITR_W-1:ITR_W-DIVISOR_W]};
        assign quotient_temp = ((|divisor_itr_r[DIVISOR_ITR-1:DIVISOR_ITR-DIVISOR_W])==0) ? {DIVISOR_W{1'b0}} : dividend_rem[(DIVIDEND_W-1):0];

        if(ITR_REMAINDER_CPD_PIUS1 == 1)begin
            reg  [DIVISOR_W-1:0]remainder_r={DIVISOR_W{1'b0}};
            reg  [DIVISOR_W-1:0]divisor_fract_r={DIVISOR_W{1'b0}};
            reg  [DIVIDEND_W-1:0] quotient_r={DIVIDEND_W{1'b0}};

            always @(posedge clk or negedge rst_n)
                if(!rst_n)begin
                    remainder_r <= {DIVISOR_W {1'b0}};
                    divisor_fract_r <= {DIVISOR_W {1'b0}};
                    quotient_r <= {DIVIDEND_W {1'b0}};
                end
                else if(clk_en) begin
                    remainder_r <= remainder_temp[DIVISOR_W-1:0];
                    divisor_fract_r <= divisor_itr_r[DIVISOR_ITR-1:DIVISOR_ITR-DIVISOR_W];
                    quotient_r <= quotient_temp;
                end

            assign remainder = remainder_r;
            assign quotient = quotient_r;
            assign divisor_fract = divisor_fract_r;
        end
        else begin
            assign remainder = remainder_temp[DIVISOR_W-1:0];
            assign quotient = quotient_temp;
            assign divisor_fract = divisor_itr_r[DIVISOR_ITR-1:DIVISOR_ITR-DIVISOR_W];  
        end
    end
endgenerate

generate
    if(Remainder_Type==1)begin
       
        always @(posedge clk or negedge rst_n)
            if(!rst_n)begin
                dividend_fract_itr_r <= {DIVIDEND_FRACT_ITR {1'b0}};
            end
            else if(clk_en) begin
                dividend_fract_itr_r <= dividend_fract_itr;
            end

        
        always@(posedge clk or negedge rst_n)
            if(!rst_n)begin
                divisor_fract_itr_r <= {DIVISOR_FRACT_ITR {1'b0}};
            end
            else if (clk_en) begin
                if (ITR_FRACT_CPD <= 1) begin
                    divisor_fract_itr_r <= divisor_fract;
                end
                else begin
                    divisor_fract_itr_r[DIVISOR_FRACT_ITR-1 : DIVISOR_W] <=
                    divisor_fract_itr_r[(DIVISOR_FRACT_ITR-1 - DIVISOR_W):0];
                    divisor_fract_itr_r[DIVISOR_W-1:0] <= divisor_fract;
                end
            end
            else begin
                divisor_fract_itr_r <= divisor_fract_itr_r;
            end
            
        if(ITR_FRACT_CPD <= 1)begin
       // reg quotient_itr_r=0;
        //assign quotient_itr = quotient_itr_r;
            always @(posedge clk or negedge rst_n)
                if(!rst_n) begin
                    quotient_fract_itr_r <= {QUOTIENT_FRACT_ITR{1'b0}};
                end 
                else if(clk_en) begin
                    quotient_fract_itr_r <= quotient_init;
                end
        end
        else begin
            if(ITR_FRACT_CPD==2)begin
                always @(posedge clk or negedge rst_n)
                    if(!rst_n) begin
                        quotient_fract_itr_r <= {(QUOTIENT_FRACT_ITR){1'b0}};
                    end 
                    else if(clk_en) begin
                // Unroll the iteration for DIVI_ADDQ_W times using generate for loop

//                        quotient_fract_itr_r[QUOTIENT_FRACT_ITR-1:QUOTIENT_FRACT_ITR-DIVI_ITR_MODE] <= quotient_fract_itr_r[DIVI_ITR_MODE-1:0];                
//                        quotient_fract_itr_r[QUOTIENT_FRACT_INIT-1:0] <= quotient_init[QUOTIENT_FRACT_INIT-1:0];                        
                        quotient_fract_itr_r[QUOTIENT_FRACT_INIT-1:0] <= quotient_init[QUOTIENT_FRACT_INIT-1:0];
                        quotient_fract_itr_r[QUOTIENT_FRACT_ITR-1:QUOTIENT_FRACT_ITR-DIVI_ITR_MODE] <= quotient_fract_itr_r[DIVI_ITR_MODE-1:0]; ///?????????###
                    end
            end
            else begin ///??????????????????????????
                integer k;
                integer m;
//                wire [127:0]test1 =  quotient_fract_itr_r[127:0];
//                wire [127:0]test2 =  quotient_fract_itr_r[4*64-1:128];
//                 Generate block to control the assignment of the dividend based on the Remainder_Type
//                assign quotient_itr = {quotient_itr_r,quotient_init};
//                 Always block to control the divisor iteration register
                
                
                always @(posedge clk or negedge rst_n)
                    if(!rst_n) begin
                        quotient_fract_itr_r <= {(QUOTIENT_FRACT_ITR){1'b0}};
                    end
                    else if(clk_en) begin
                // Unroll the iteration for DIVI_ADDQ_W times using generate for loop
                        quotient_fract_itr_r[QUOTIENT_FRACT_INIT-1:0] <= quotient_init[QUOTIENT_FRACT_INIT-1:0];
                        for(k=0;k<ITR_FRACT_CPD-1;k=k+1) begin: fract 
                            for(m=0;m<ITR_FRACT_CPD-k-1;m=m+1) begin: fract_bit 
                               quotient_fract_itr_r[(((2*ITR_FRACT_CPD-k)*(k+1)>>1)+m*DIVI_ITR_MODE) +:DIVI_ITR_MODE]
                            <= quotient_fract_itr_r[((((2*ITR_FRACT_CPD-k+1)*k)>>1)+m*DIVI_ITR_MODE) +:DIVI_ITR_MODE] ;
                            end
                        end
//                         quotient_fract_itr_r[QUOTIENT_FRACT_INIT-1:0] <= quotient_init[QUOTIENT_FRACT_INIT-1:0];                                       
                    end






            end
        end
    end
endgenerate

generate
    if (Remainder_Type == 1) begin // If the number of clock cycles per division is one, start the iteration block
        if(ITR_FRACT_CPD==0)begin
        ipsxe_divider_iteration_fract_nx_v1_0 #(.DIVI_ADDQ_W(DIVISOR_W), .DIVI_ITR_REM(QUOTIENT_FRACT_W)) u_ipsxe_divider_iteration_fract_nx_v1_0(
                       .dividend_2n({{1'b0},remainder}),
                       .divisor_2n({{(2){1'b0}},divisor_fract}),
                       .dividend_2n_final(dividend_fract_itr[DIVIDEND_FRACT_ITR-1:0]),
                       .quotient_bit(quotient_init[QUOTIENT_FRACT_W-1:0]));
        assign fraction = quotient_fract_itr_r;
        end
        else begin
        
              reg [QUOTIENT_FRACT_INIT*ITR_FRACT_CPD-1:0]fraction_reg={QUOTIENT_FRACT_INIT*ITR_FRACT_CPD{1'b0}};
              wire [QUOTIENT_FRACT_INIT*ITR_FRACT_CPD-1:0]fraction_r;
              integer j;
                        always@(posedge clk or negedge rst_n)
                            if(!rst_n)begin
                                fraction_reg <= 'd0;
                            end
                            else if (clk_en) begin
                                    fraction_reg <=  fraction_reg << QUOTIENT_FRACT_INIT;
                                    for (j=0;j<ITR_FRACT_CPD;j=j+1) begin
                                        fraction_reg[(((j+1) * QUOTIENT_FRACT_INIT - 1) - (j * DIVI_ITR_MODE)) -:DIVI_ITR_MODE] <= quotient_init[(((1+j)*DIVI_ITR_MODE-1)) -:DIVI_ITR_MODE];
                                    end                                                                     
                                end
                            else begin
                                fraction_reg <= fraction_reg;
                            end
                
            if(ITR_FRACT_CPD==1)begin
//            ipsxe_divider_iteration_fract_nx_v1_0 #(.DIVI_ADDQ_W(DIVISOR_W), .DIVI_ITR_REM(DIVI_ITR_MODE)) u_ipsxe_divider_iteration_fract_nx_v1_0(
//                           .dividend_2n({{1'b0},remainder}),
//                           .divisor_2n({{(2){1'b0}},divisor_fract}),
//                           .dividend_2n_final(dividend_fract_itr[DIVIDEND_FRACT_ITR-1:0]),
//                           .quotient_bit(quotient_init[DIVI_ITR_MODE-1:0]));
                           
                           
                           
            ipsxe_divider_iteration_fract_nx_v1_0 #(.DIVI_ADDQ_W(DIVISOR_W), .DIVI_ITR_REM(DIVI_ITR_MODE)) u_ipsxe_divider_iteration_fract_nx_v1_0(
                           .dividend_2n({{1'b0},remainder}),
                           .divisor_2n({{(2){1'b0}},divisor_fract}),
                           .dividend_2n_final(dividend_fract_itr[DIVIDEND_FRACT_ITR-1:0]),
                           .quotient_bit(quotient_init[DIVI_ITR_MODE-1:0]));
                           
            end
            
            else begin
                genvar i;
                // Unroll the iteration for DIVI_ADDQ_W times using generate for loop
                for(i=0;i<ITR_FRACT_CPD;i=i+1) begin: iteration_n
                    if(i==0)begin
                        // For the first iteration, use the initial dividend and divisor inputs
                        ipsxe_divider_iteration_fract_nx_v1_0 #(.DIVI_ADDQ_W(DIVISOR_W), .DIVI_ITR_REM(DIVI_ITR_MODE)) u_ipsxe_divider_iteration_fract_nx_v1_0(
                                                       .dividend_2n({{1'b0},remainder}),
                                                       .divisor_2n ({{(2){1'b0}},divisor_fract}),
                                                       .dividend_2n_final(dividend_fract_itr[DIVISOR_W:0]),
                                                       .quotient_bit (quotient_init[DIVI_ITR_MODE-1:0]));
                    end
                    else begin
                        // For all other iterations, use the outputs from previous iterations
                        if(i==(ITR_FRACT_CPD-1))begin
                            // For the last iteration, also account for the sign of the dividend
                            ipsxe_divider_iteration_fract_nx_v1_0 #(.DIVI_ADDQ_W(DIVISOR_W), .DIVI_ITR_REM(DIVI_ITR_MODE)) u_ipsxe_divider_iteration_fract_nx_v1_0(
                                                           .dividend_2n(dividend_fract_itr_r[i*(DIVISOR_W+1)-1:(i-1)*(DIVISOR_W+1)]),
                                                           .divisor_2n({{(2){1'b0}},divisor_fract_itr_r[i*DIVISOR_W-1:(i-1)*DIVISOR_W]}),
                                                           .dividend_2n_final(dividend_fract_itr[(i+1)*(DIVISOR_W+1)-1:i*(DIVISOR_W+1)]),
                                                           .quotient_bit(quotient_init[QUOTIENT_FRACT_INIT-1:QUOTIENT_FRACT_INIT-DIVI_ITR_MODE]));
                        end
                        else begin
                            ipsxe_divider_iteration_fract_nx_v1_0 #(.DIVI_ADDQ_W(DIVISOR_W), .DIVI_ITR_REM(DIVI_ITR_MODE)) u_ipsxe_divider_iteration_fract_nx_v1_0(
                                                           .dividend_2n(dividend_fract_itr_r[i*(DIVISOR_W+1)-1:(i-1)*(DIVISOR_W+1)]),
                                                           .divisor_2n({{(2){1'b0}},divisor_fract_itr_r[i*DIVISOR_W-1:(i-1)*DIVISOR_W]}),
                                                           .dividend_2n_final(dividend_fract_itr[(i+1)*(DIVISOR_W+1)-1:i*(DIVISOR_W+1)]),
                                                           .quotient_bit(quotient_init[(i+1)*(DIVI_ITR_MODE)-1:i*(DIVI_ITR_MODE)]));
                        end
                    end
                end
            end


   
//                 genvar i;
//                // Unroll the iteration for DIVI_ADDQ_W times using generate for loop
//                for(i=0;i<ITR_FRACT_CPD;i=i+1) begin: iteration_n
//                    if(i==0)begin
//                        // For the first iteration, use the initial dividend and divisor inputs
//                        ipsxe_divider_iteration_fract_nx_v1_0 #(.DIVI_ADDQ_W(DIVISOR_W), .DIVI_ITR_REM(DIVI_ITR_MODE)) u_ipsxe_divider_iteration_fract_nx_v1_0(
//                                                       .dividend_2n({{1'b0},remainder}),
//                                                       .divisor_2n ({{(2){1'b0}},divisor_fract}),
//                                                       .dividend_2n_final(dividend_fract_itr[DIVISOR_W:0]),
//                                                       .quotient_bit (fraction_r[QUOTIENT_FRACT_INIT-1:QUOTIENT_FRACT_INIT-DIVI_ITR_MODE]));
//                    end
//                    else begin
//                        // For all other iterations, use the outputs from previous iterations
//                        if(i==(ITR_FRACT_CPD-1))begin
//                            // For the last iteration, also account for the sign of the dividend
//                            ipsxe_divider_iteration_fract_nx_v1_0 #(.DIVI_ADDQ_W(DIVISOR_W), .DIVI_ITR_REM(DIVI_ITR_MODE)) u_ipsxe_divider_iteration_fract_nx_v1_0(
//                                                           .dividend_2n(dividend_fract_itr_r[i*(DIVISOR_W+1)-1:(i-1)*(DIVISOR_W+1)]),
//                                                           .divisor_2n({{(2){1'b0}},divisor_fract_itr_r[i*DIVISOR_W-1:(i-1)*DIVISOR_W]}),
//                                                           .dividend_2n_final(dividend_fract_itr[(i+1)*(DIVISOR_W+1)-1:i*(DIVISOR_W+1)]),
//                                                           .quotient_bit(fraction_r[(i+1)*(QUOTIENT_FRACT_INIT)-1-i*DIVI_ITR_MODE:(i+1)*(QUOTIENT_FRACT_INIT)-(i+1)*DIVI_ITR_MODE]));
//                        end
//                        else begin
//                            ipsxe_divider_iteration_fract_nx_v1_0 #(.DIVI_ADDQ_W(DIVISOR_W), .DIVI_ITR_REM(DIVI_ITR_MODE)) u_ipsxe_divider_iteration_fract_nx_v1_0(
//                                                           .dividend_2n(dividend_fract_itr_r[i*(DIVISOR_W+1)-1:(i-1)*(DIVISOR_W+1)]),
//                                                           .divisor_2n({{(2){1'b0}},divisor_fract_itr_r[i*DIVISOR_W-1:(i-1)*DIVISOR_W]}),
//                                                           .dividend_2n_final(dividend_fract_itr[(i+1)*(DIVISOR_W+1)-1:i*(DIVISOR_W+1)]),
//                                                           .quotient_bit(fraction_r[(i+1)*(QUOTIENT_FRACT_INIT)-1-i*DIVI_ITR_MODE:(i+1)*(QUOTIENT_FRACT_INIT)-(i+1)*DIVI_ITR_MODE]));
//                        end
//                    end
//                end
//            end
       
//            genvar n;
//            for(n=0;n<ITR_FRACT_CPD;n=n+1) begin: fract 
//               assign fraction[QUOTIENT_FRACT_W-n*DIVI_ITR_MODE-1:QUOTIENT_FRACT_W-(n+1)*DIVI_ITR_MODE] = quotient_fract_itr_r[(QUOTIENT_FRACT_ITR-(((n+1)*n>>1))*DIVI_ITR_MODE-1):QUOTIENT_FRACT_ITR-(((n+1)*n>>1)+1)*DIVI_ITR_MODE];
//            end

               assign fraction[QUOTIENT_FRACT_W-1:DIVI_ITR_FRACT_REM] = fraction_reg[QUOTIENT_FRACT_INIT*ITR_FRACT_CPD-1:QUOTIENT_FRACT_INIT*ITR_FRACT_CPD-QUOTIENT_FRACT_INIT];



        end

        if(DIVI_ITR_FRACT_REM==0)begin
        end
        else begin
            //assign fraction = fraction << (QUOTIENT_FRACT_W-QUOTIENT_FRACT_INIT);
            
            ipsxe_divider_iteration_fract_nx_v1_0 #(.DIVI_ADDQ_W(DIVISOR_W), .DIVI_ITR_REM(DIVI_ITR_FRACT_REM)) u_ipsxe_divider_iteration_fract_nx_v1_0(
                                                           .dividend_2n(dividend_fract_itr_r[DIVIDEND_FRACT_ITR-1:DIVIDEND_FRACT_ITR-DIVISOR_W-1]),
                                                           .divisor_2n({{(2){1'b0}},divisor_fract_itr_r[DIVISOR_FRACT_ITR-1:DIVISOR_FRACT_ITR-DIVISOR_W]}),
                                                           .dividend_2n_final(),
                                                           .quotient_bit(fraction[DIVI_ITR_FRACT_REM-1 : 0]));
//                                                           .quotient_bit(fraction[QUOTIENT_FRACT_W-1-QUOTIENT_FRACT_INIT : 0]));
        end
       
        ipsxe_divider_register_nx_v1_0 #(.A_WIDTH(DIVIDEND_W), 
                    .B_WIDTH(),
                    .LATENCY(ITR_FRACT_CPD_NOTZERO)
                    )u_ipsxe_divider_register_nx_v1_0 (
                    .clk(clk), 
                    .rst_n(rst_n), 
                    .clk_en(clk_en),
                    .adata(quotient),
                    .bdata(),
                    .adata_latency(quotient_fra),
                    .bdata_latency()
                    ); 
    end 
endgenerate
//based on the value of Remainder_Type, determine how the values for quotient_temp, quotient_fract_temp, and remainder_temp are assigned . 
//If Remainder_Type is 1, the quotient is divided into two parts: an integral part (quotient_temp) and a fractional part (quotient_fract_temp). 
//If Remainder_Type is not 1, the entire quotient is assigned to quotient_temp and the remainder to remainder_temp.
generate
    if(DIVI_ITR_PIPE==0)begin
        if (Remainder_Type == 1) begin
            assign quotient_out = quotient_fra;
            assign quotient_fract_out = fraction;
        end 
        else begin
            assign quotient_out =  quotient;
            assign remainder_out = remainder;
        end
    end
    else begin
        // wire    [QUOTIENT_FRACT_W-1:0]quotient_fract_latency;
        // wire    [DIVISOR_W-1:0]remainder_latency;
        // wire    [DIVIDEND_W-1:0]quotient_latency;
        if (Remainder_Type == 1) begin
            // assign quotient_latency = quotient[(QUOTIENT_FRACT_W+DIVIDEND_W-1):QUOTIENT_FRACT_W];
            // assign quotient_fract_latency = quotient[QUOTIENT_FRACT_W-1:0];
            ipsxe_divider_register_nx_v1_0 #(.A_WIDTH(DIVIDEND_W), 
                     .B_WIDTH(QUOTIENT_FRACT_W),
                     .LATENCY(DIVI_ITR_PIPE)
            )u_ipsxe_divider_register_nx_v1_0 (
                    .clk(clk), 
                    .rst_n(rst_n), 
                    .clk_en(clk_en),
                    .adata(quotient_fra),
                    .bdata(fraction),
                    .adata_latency(quotient_out),
                    .bdata_latency(quotient_fract_out)
                    );
        end 
        else begin
            // assign quotient_latency =  quotient[DIVIDEND_W-1:0];
            // assign remainder_latency = remainder[DIVISOR_W-1:0];
            ipsxe_divider_register_nx_v1_0 #(.A_WIDTH(DIVIDEND_W), 
                     .B_WIDTH(DIVISOR_W),
                     .LATENCY(DIVI_ITR_PIPE)
            )u_ipsxe_divider_register_nx_v1_0 (
                    .clk(clk), 
                    .rst_n(rst_n), 
                    .clk_en(clk_en),
                    .adata(quotient),
                    .bdata(remainder),
                    .adata_latency(quotient_out),
                    .bdata_latency(remainder_out)
                    );
        end
    end
endgenerate

endmodule