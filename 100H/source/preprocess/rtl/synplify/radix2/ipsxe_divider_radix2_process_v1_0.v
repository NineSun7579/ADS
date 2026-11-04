
// divider process
//latency:DIVI_ADDQ_W+1(in this module)
module ipsxe_divider_radix2_process_v1_0
#(
    parameter DIVIDEND_W = 8,                    // Width of the dividend
    parameter DIVISOR_W = 8,                     // Width of the divisor
    parameter QUOTIENT_FRACT_W = 8,         // Width of the fractional part of the quotient
    parameter CLK_PER_DIVISION = 1,                  // Clock cycles per division
    parameter CNT_WIDTH = 1,                         // Width of the count signal
    parameter Remainder_Type = 1 ,                   // Type of remainder
    parameter SIGNED = 0
)
(
    input        clk,
    input        rst_n,
    input        clk_en,
    input        [CNT_WIDTH:0]cnt,
    input        [DIVIDEND_W-1:0] dividend,
    input        [DIVISOR_W-1:0] divisor,
    output   wire   [QUOTIENT_FRACT_W-1:0]quotient_fract,
    output   reg    [DIVISOR_W-1:0]remainder = {DIVISOR_W{1'b0}},

    output   reg    [DIVIDEND_W-1:0]quotient = {DIVIDEND_W{1'b0}}

   );

parameter CNT_FRACT = (CLK_PER_DIVISION==1) ? 1'b0 : 
                      ((DIVIDEND_W-(DIVIDEND_W>>(CNT_WIDTH+1)) * CLK_PER_DIVISION) == 0) ? CLK_PER_DIVISION-1'b1 : (DIVIDEND_W-(DIVIDEND_W>>(CNT_WIDTH+1)) * CLK_PER_DIVISION)-1'b1;

// Calculate the number of iterations needed for division based on the width of the dividend + quotient and the number of clock cycles per division
// Generate block to control the assignment of the dividend based on the Remainder_Type
// Generate block to control the iteration process depending on whether SIGNED is 1 or not
wire    [DIVISOR_W-1:0]   remainder_temp;
wire    [DIVIDEND_W-1:0]  quotient_temp;
wire    [DIVISOR_W-1:0]   divisor_fract;


//remainder
ipsxe_divider_radix2_remainder_v1_0#(
     .DIVIDEND_W (DIVIDEND_W),
     .DIVISOR_W  (DIVISOR_W),
     .CLK_PER_DIVISION(CLK_PER_DIVISION ),
     .CNT_WIDTH  (CNT_WIDTH ),
     .SIGNED(SIGNED)
    )
 u_ipsxe_divider_radix2_remainder_v1_0(
    .clk         (clk),
    .rst_n       (rst_n),
    .clk_en      (clk_en),
    .cnt         (cnt),
    .dividend    (dividend),
    .divisor     (divisor),
    .remainder   (remainder_temp),
    .quotient    (quotient_temp),
    .divisor_fract(divisor_fract)
);

//fraction
generate
    if(Remainder_Type==1)begin//fractional type

        wire [DIVIDEND_W-1:0]quotient_r;
        wire [CNT_WIDTH:0]cnt_fract;
        reg     [CNT_WIDTH:0]cnt_r= {(CNT_WIDTH+1){1'b0}};
        
        ipsxe_divider_radix2_fract_v1_0 #(
             .DIVISOR_W  (DIVISOR_W),
             .QUOTIENT_FRACT_W(QUOTIENT_FRACT_W),
             .CLK_PER_DIVISION(CLK_PER_DIVISION ),
             .CNT_WIDTH  (CNT_WIDTH)
//             .CNT_FRACT(CNT_FRACT)
            )
         u_ipsxe_divider_radix2_fract_v1_0(
            .clk         (clk),
            .rst_n       (rst_n),
            .clk_en      (clk_en),
            .cnt         (cnt_fract),
            .dividend    (remainder_temp),
            .divisor     (divisor_fract),
            .fraction    (quotient_fract)
        );
//shirt reg for quotient
        
        
        assign cnt_fract = (cnt_r >= CNT_FRACT) ? (cnt_r - CNT_FRACT) : CLK_PER_DIVISION - ( CNT_FRACT - cnt_r);

        always @(posedge clk or negedge rst_n)
            if(!rst_n) begin
                cnt_r <= {(CNT_WIDTH+1){1'b0}};           
            end else if(clk_en) begin
                cnt_r <= cnt;
            end
//       ipsxe_divider_radix2_distributed_shiftregister_wrapper_v1_3  #(
//    	.FIXED_DEPTH(QUOTIENT_FRACT_W),
//    	.DATA_WIDTH(DIVIDEND_W)
//         ) u_ipm_distributed_shiftregister_wrapper_v1_3 (
//    	.din(quotient_temp),
//    	.clk(clk),
//    	.i_aclken(clk_en),
//    	.rst(!rst_n),
//    	.dout(quotient_r)
//        );
        ipsxe_divider_register_nx_v1_0 #(.A_WIDTH(DIVIDEND_W),.B_WIDTH(),.LATENCY(QUOTIENT_FRACT_W)) u_ipsxe_divider_register_nx_v1_0(
                                    .clk(clk),
                                    .rst_n(rst_n),
                                    .clk_en(clk_en),
                                    .adata(quotient_temp),
                                    .bdata(),
                                    .adata_latency(quotient_r),
                                    .bdata_latency());

        always @(posedge clk or negedge rst_n)
            if(!rst_n) begin
                quotient <= {DIVIDEND_W{1'b0}};           
            end else if(clk_en) begin
                quotient <= quotient_r;
            end
    end
    else begin//remainder type
        always @(posedge clk or negedge rst_n)
            if(!rst_n) begin
                remainder <= {DIVISOR_W {1'b0}};
                quotient  <= {DIVIDEND_W{1'b0}};           
            end 
            else if(clk_en) begin
                quotient  <= quotient_temp;
                remainder <= remainder_temp;
            end
    end
endgenerate

endmodule