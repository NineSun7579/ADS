
// divider process
//latency:DIVI_ADDQ_W+1(in this module)
module ipsxe_divider_radix2_fract_v1_0
(
    clk,
    rst_n,
    clk_en,
    cnt,
    dividend,
    divisor,
    fraction
   );
   
parameter    DIVISOR_W=8;
parameter    QUOTIENT_FRACT_W=8;
parameter    CLK_PER_DIVISION = 1;
parameter    CNT_WIDTH = 1;
//parameter    CNT_FRACT = 1;
parameter    QUOTIENT_ITR =  ((1+QUOTIENT_FRACT_W)*(QUOTIENT_FRACT_W))>>1;
// Calculate the number of iterations needed for division based on the width of the dividend + quotient and the number of clock cycles per division
// Width of dividend for each iteration
localparam   DIVI_ITR = (QUOTIENT_FRACT_W <= (CLK_PER_DIVISION))?1:(QUOTIENT_FRACT_W>((QUOTIENT_FRACT_W>>($clog2(CLK_PER_DIVISION)))*CLK_PER_DIVISION))?
    ((QUOTIENT_FRACT_W>>$clog2(CLK_PER_DIVISION))+1):(QUOTIENT_FRACT_W>>($clog2(CLK_PER_DIVISION)));

localparam   DIVIDEND_ITR = (DIVISOR_W + 1 ) * DIVI_ITR;

localparam   DIVISOR_ITR = DIVISOR_W * DIVI_ITR;
// Flag to determine if there are multiple iterations (when CLK_PER_DIVISION is not 1)
// localparam   ITERATION_WIDTH = Remainder_Type ? QUOTIENT_FRACT_W + DIVIDEND_W : DIVIDEND_W;

input        clk;
input        rst_n;
input        clk_en;
input        [CNT_WIDTH:0]cnt;
input        [DIVISOR_W-1:0] dividend;
input        [DIVISOR_W-1:0] divisor;

output   reg    [QUOTIENT_FRACT_W-1:0]fraction= {QUOTIENT_FRACT_W{1'b0}};

// wire   [DIVISOR_W + 1:0] dividend_2n; //2 sign bit
// wire   [DIVISOR_W + 1:0] divisor_2n; //2 sign bit
wire   [(DIVIDEND_ITR-1):0] dividend_itr;
wire   [(DIVIDEND_ITR-1):0]dividend_itr_cpd;
wire   [DIVISOR_ITR-1:0]divisor_itr_cpd;   
wire   [QUOTIENT_FRACT_W-1:0] quotient_init;
//wire   [QUOTIENT_ITR-1:0] quotient_itr;

reg    [(DIVIDEND_ITR-1):0] dividend_itr_r = {DIVIDEND_ITR{1'b0}};
reg    [(DIVISOR_ITR-1):0] divisor_itr_r = {DIVIDEND_ITR{1'b0}};  
reg    [QUOTIENT_ITR-1:0] quotient_itr_r = {QUOTIENT_ITR{1'b0}};
always @(posedge clk or negedge rst_n)
    if(!rst_n)begin
        dividend_itr_r <= {DIVIDEND_ITR {1'b0}};
    end
    else if(clk_en) begin
        dividend_itr_r <= dividend_itr;
    end

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

generate
    if(QUOTIENT_FRACT_W == 1)begin
       // reg quotient_itr_r;
        //assign quotient_itr = quotient_itr_r;
        always @(posedge clk or negedge rst_n)
            if(!rst_n) begin
                quotient_itr_r <= 1'b0;
            end 
            else if(clk_en) begin
                quotient_itr_r <= quotient_init;
            end
    end
    else begin
        if(QUOTIENT_FRACT_W==2)begin
        
            always @(posedge clk or negedge rst_n)
                if(!rst_n) begin
                    quotient_itr_r <= {(QUOTIENT_ITR){1'b0}};
                end 
                else if(clk_en) begin
            // Unroll the iteration for DIVI_ADDQ_W times using generate for loop
                    quotient_itr_r[QUOTIENT_FRACT_W-1:0] <= quotient_init[QUOTIENT_FRACT_W-1:0];
                    quotient_itr_r[QUOTIENT_ITR-1] <= quotient_itr_r[0];
                end
        end
        else begin
            //reg    [QUOTIENT_ITR-1:0] quotient_itr_r;
            integer k;
            integer m;
            // Generate block to control the assignment of the dividend based on the Remainder_Type
            //assign quotient_itr = {quotient_itr_r,quotient_init};
            // Always block to control the divisor iteration register
            always @(posedge clk or negedge rst_n)
                if(!rst_n) begin
                    quotient_itr_r <= {(QUOTIENT_ITR){1'b0}};
                end
                else if(clk_en) begin
            // Unroll the iteration for DIVI_ADDQ_W times using generate for loop
                    quotient_itr_r[QUOTIENT_FRACT_W-1:0] <= quotient_init[QUOTIENT_FRACT_W-1:0];
                    for(k=0;k<QUOTIENT_FRACT_W-1;k=k+1) begin: fract 
                        for(m=0;m<QUOTIENT_FRACT_W-k-1;m=m+1) begin: fract_bit 
                           quotient_itr_r[((2*QUOTIENT_FRACT_W-k)*(k+1)>>1)+m]
                        <= quotient_itr_r[(((2*QUOTIENT_FRACT_W-k+1)*k)>>1)+m] ;
//                        // quotient_itr_r[(((2*QUOTIENT_FRACT_W-k+1)*k)>>1)+:(QUOTIENT_FRACT_W-k)] 
//                        // <= quotient_itr_r[((2*QUOTIENT_FRACT_W-k)*(k+1)>>1)+:(QUOTIENT_FRACT_W-k-1)];
//                        // quotient_itr_r[((((2*QUOTIENT_FRACT_W-k+1)*k)>>1)+(QUOTIENT_FRACT_W-k-1)):(((2*QUOTIENT_FRACT_W-k+1)*k)>>1)] 
//                        // <= quotient_itr_r[((2*QUOTIENT_FRACT_W-k)*(k+1)>>1)+(QUOTIENT_FRACT_W-k-2):((2*QUOTIENT_FRACT_W-k)*(k+1)>>1)];
                       end
                   end
                end
        end
    end
endgenerate
// generate
//     genvar k;
//         for(k=0;k<QUOTIENT_FRACT_W;k=k+1) begin: quotient_iteration_n
//             alw
//             ipsxe_divider_register_nx_v1_0 #(.A_WIDTH(QUOTIENT_FRACT_W-1-k),B_WIDTH(),LATENCY(1)) u_ipsxe_divider_register_nx_v1_0(
//                                         .clk(clk),
//                                         .rst_n(rst_n),
//                                         .clk_en(clk_en),
//                                         .adata(quotient_itr[((2*QUOTIENT_FRACT_W-k)*(k+1)>>1)+:(QUOTIENT_FRACT_W-k)]),
//                                         .bdata(),
//                                         .adata_latency(quotient_itr[((2*QUOTIENT_FRACT_W-k-1)*(k+2)>>1)+:(QUOTIENT_FRACT_W-k-1)])
//                                         .bdata_latency());
//             end
// endgenerate

generate
    if (CLK_PER_DIVISION == 1) begin // If the number of clock cycles per division is one, start the iteration block
     
        genvar i;
        // Unroll the iteration for DIVI_ADDQ_W times using generate for loop
        for(i=0;i<QUOTIENT_FRACT_W;i=i+1) begin: iteration_n
            if(i==0)begin
                // For the first iteration, use the initial dividend and divisor inputs
                ipsxe_divider_iteration_fract_v1_0 #(.DIVI_ADDQ_W(DIVISOR_W)) u_ipsxe_divider_iteration_fract_v1_0(
                                               .dividend_2n({{1'b0},dividend}),
                                               .divisor_2n ({{(2){1'b0}},divisor}),
                                               .dividend_2n_final(dividend_itr[DIVISOR_W:0]),
                                               .quotient_bit (quotient_init[0]));
            end
            else begin
                // For all other iterations, use the outputs from previous iterations
                if(i==(QUOTIENT_FRACT_W-1))begin
                    // For the last iteration, also account for the sign of the dividend
                    ipsxe_divider_iteration_fract_v1_0 #(.DIVI_ADDQ_W(DIVISOR_W)) u_ipsxe_divider_iteration_fract_v1_0(
//                                                   .dividend_2n(dividend_itr_r[i*(DIVISOR_W+1)-1:(i-1)*(DIVISOR_W+1)]),
                                                   .dividend_2n(dividend_itr_r[i*(DIVISOR_W+1)-1:(i-1)*(DIVISOR_W+1)]),
                                                   .divisor_2n({{(2){1'b0}},divisor_itr_r[i*DIVISOR_W-1:(i-1)*DIVISOR_W]}),
                                                   .dividend_2n_final(dividend_itr[(i+1)*(DIVISOR_W+1)-1:i*(DIVISOR_W+1)]),
                                                   .quotient_bit(quotient_init[QUOTIENT_FRACT_W-1]));
                end
                else begin
                    ipsxe_divider_iteration_fract_v1_0 #(.DIVI_ADDQ_W(DIVISOR_W)) u_ipsxe_divider_iteration_fract_v1_0(
                                                   .dividend_2n(dividend_itr_r[i*(DIVISOR_W+1)-1:(i-1)*(DIVISOR_W+1)]),
                                                   .divisor_2n({{(2){1'b0}},divisor_itr_r[i*DIVISOR_W-1:(i-1)*DIVISOR_W]}),
                                                   .dividend_2n_final(dividend_itr[(i+1)*(DIVISOR_W+1)-1:i*(DIVISOR_W+1)]),
                                                   .quotient_bit(quotient_init[i]));
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
        wire    [DIVI_ITR-1:0]quotient_cnt;
        reg     [QUOTIENT_FRACT_W-1:0] quotient_ini = {QUOTIENT_FRACT_W{1'b0}};
        
        assign  quotient_init = quotient_ini;
        assign  dividend_itr_cpd[DIVISOR_W:0]  = (cnt == 0) ? {{1'b0},dividend}:dividend_itr_r[DIVISOR_W:0];
        assign  divisor_itr_cpd[DIVISOR_W-1:0] = (cnt == 0) ? divisor:divisor_itr_r[DIVISOR_W-1:0];
        genvar i;
        for(i=0;i<DIVI_ITR;i=i+1) begin: iteration_n
            always @(*)begin
                if(cnt == 0) quotient_ini[i*CLK_PER_DIVISION] = quotient_cnt[i]; 
                else  if(cnt == 0) quotient_ini[i*CLK_PER_DIVISION]   = quotient_cnt[i]; 
                else  if(cnt == 1) quotient_ini[i*CLK_PER_DIVISION+1] = quotient_cnt[i]; 
                else  if(cnt == 2) quotient_ini[i*CLK_PER_DIVISION+2] = quotient_cnt[i]; 
                else  if(cnt == 3) quotient_ini[i*CLK_PER_DIVISION+3] = quotient_cnt[i]; 
                else  if(cnt == 4) quotient_ini[i*CLK_PER_DIVISION+4] = quotient_cnt[i]; 
                else  if(cnt == 5) quotient_ini[i*CLK_PER_DIVISION+5] = quotient_cnt[i]; 
                else  if(cnt == 6) quotient_ini[i*CLK_PER_DIVISION+6] = quotient_cnt[i]; 
                else  if(cnt == 7) quotient_ini[i*CLK_PER_DIVISION+7] = quotient_cnt[i]; 
            end
            if(i==0)begin
                ipsxe_divider_iteration_fract_v1_0 #(.DIVI_ADDQ_W(DIVISOR_W)) u_ipsxe_divider_iteration_fract_v1_0(
                                               .dividend_2n(dividend_itr_cpd[DIVISOR_W:0]),
                                               .divisor_2n({{2{1'b0}}, divisor_itr_cpd[DIVISOR_W-1:0]}),
                                               .dividend_2n_final(dividend_itr[DIVISOR_W:0]),
                                               .quotient_bit (quotient_cnt[0]));
            end
            else begin
                if(i==(DIVI_ITR-1))begin
                    assign  dividend_itr_cpd[(i+1)*(DIVISOR_W+1)-1:i*(DIVISOR_W+1)] = (cnt == 0)?
                            dividend_itr_r[i*(DIVISOR_W+1)-1:(i-1)*(DIVISOR_W+1)]:
                            dividend_itr_r[(i+1)*(DIVISOR_W+1)-1:i*(DIVISOR_W+1)];
                    assign  divisor_itr_cpd[(i+1)*DIVISOR_W-1:i*DIVISOR_W] = (cnt == 0)?
                            divisor_itr_r[i*DIVISOR_W-1:(i-1)*DIVISOR_W]:
                            divisor_itr_r[(i+1)*DIVISOR_W-1:i*DIVISOR_W];
                    ipsxe_divider_iteration_fract_v1_0 #(.DIVI_ADDQ_W(DIVISOR_W)) u_ipsxe_divider_iteration_fract_v1_0(
                                                   .dividend_2n(dividend_itr_cpd[(i+1)*(DIVISOR_W+1)-1:i*(DIVISOR_W+1)]),
                                                   .divisor_2n({{2{1'b0}},divisor_itr_cpd[(i+1)*DIVISOR_W-1:i*DIVISOR_W]}),
                                                   .dividend_2n_final(dividend_itr[(i+1)*(DIVISOR_W+1)-1:i*(DIVISOR_W+1)]),
                                                   .quotient_bit (quotient_cnt[i]));
                end
                else begin
                    assign  dividend_itr_cpd[(i+1)*(DIVISOR_W+1)-1:i*(DIVISOR_W+1)] = (cnt == 0)?
                            dividend_itr_r[i*(DIVISOR_W+1)-1:(i-1)*(DIVISOR_W+1)]:
                            dividend_itr_r[(i+1)*(DIVISOR_W+1)-1:i*(DIVISOR_W+1)];
                    assign  divisor_itr_cpd[(i+1)*DIVISOR_W-1:i*DIVISOR_W] = (cnt == 0)?
                            divisor_itr_r[i*DIVISOR_W-1:(i-1)*DIVISOR_W]:
                            divisor_itr_r[(i+1)*DIVISOR_W-1:i*DIVISOR_W];
                    ipsxe_divider_iteration_fract_v1_0 #(.DIVI_ADDQ_W(DIVISOR_W)) u_ipsxe_divider_iteration_fract_v1_0(
                                                   .dividend_2n(dividend_itr_cpd[(i+1)*(DIVISOR_W+1)-1:i*(DIVISOR_W+1)]),
                                                   .divisor_2n({{2{1'b0}},divisor_itr_cpd[(i+1)*DIVISOR_W-1:i*DIVISOR_W]}),
                                                   .dividend_2n_final(dividend_itr[(i+1)*(DIVISOR_W+1)-1:i*(DIVISOR_W+1)]),
                                                   .quotient_bit (quotient_cnt[i]));
                end
            end
        end
    end
endgenerate
//In this code, based on the condition Remainder_Type == 0, the remainder is calculated in two ways: 
//if the most significant bit of the dividend is 1, the remainder is updated by adding a portion of the dividend and divisor together;
//otherwise, the remainder is set to be a portion of the dividend with a leading zero. 
//The quotient is calculated outside of the generate block by selecting a portion of the dividend.

//based on the value of Remainder_Type, determine how the values for quotient_temp, quotient_fract_temp, and remainder_temp are assigned . 
//If Remainder_Type is 1, the quotient is divided into two parts: an integral part (quotient_temp) and a fractional part (quotient_fract_temp). 
//If Remainder_Type is not 1, the entire quotient is assigned to quotient_temp and the remainder to remainder_temp.
integer n;
always @(posedge clk or negedge rst_n)
    if(!rst_n) begin
        fraction <= {QUOTIENT_FRACT_W{1'b0}};
    end 
    else if(clk_en) begin
// Unroll the iteration for DIVI_ADDQ_W times using generate for loop
        for(n=0;n<QUOTIENT_FRACT_W;n=n+1) begin: fract 
            fraction[QUOTIENT_FRACT_W-n-1] <= quotient_itr_r[QUOTIENT_ITR-((n+1)*n>>1)-1];
        end
    end
endmodule