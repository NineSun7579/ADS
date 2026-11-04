module ipsxe_divider_lutmult_top_v1_1 #(
    parameter DIVIDEND_WIDTH = 8, //transmit the dividend width
    parameter DIVISOR_WIDTH = 8,  //transmit the divisor width
    parameter LATENCY = 4,  //transmit the divisor width
    parameter SIGNED = 0          //transmit the signed mode
)
    (
    input clk,
    input rstn,
    input clk_en,
    input [DIVIDEND_WIDTH-1:0] dividend,
    input [DIVISOR_WIDTH-1:0] divisor,
    output [DIVIDEND_WIDTH-1:0] quotient,
    output [DIVISOR_WIDTH-1:0] remainder 
);


parameter BLOCK_LATENCY = LATENCY-1-SIGNED*2; //used for calculating the latency for ipsxe_divider_lutmult_latency_v1_0 block
parameter BLOCK_LATENCY_HIGH = LATENCY-5-SIGNED*2; //used for calculating the latency for ipsxe_divider_lutmult_latency_v1_0 block when the latency is bigger than 7


generate
if (SIGNED == 1) begin  //A generate if block. Circuit is generated only when SIGNED is 1
       wire  dividend_sign;//sign bit of dividend
       wire  divisor_sign; //sign bit of dividend
      


        wire  [DIVIDEND_WIDTH-1:0] dividend_unsigned;//The absolute value of the dividend.
        wire  [DIVISOR_WIDTH-1:0] divisor_unsigned;  //The absolute value of the divisor.
        wire [DIVIDEND_WIDTH-1:0] dividend_pass;     //As the result of fully pipelined, the input dividend should be passed with its calculation process. Got from drm and sent to core
        wire [DIVISOR_WIDTH-1:0] divisor_pass;       //As the result of fully pipelined, the input divisor should be passed with its calculation process. Got from drm and sent to core

        reg   [DIVIDEND_WIDTH-1:0] dividend_unsigned_r = {(DIVIDEND_WIDTH){1'b0}};//register of dividend_unsigned
        reg   [DIVISOR_WIDTH-1:0] divisor_unsigned_r={(DIVISOR_WIDTH){1'b0}};  //register of divisor_unsigned
        reg   dividend_sign_bit=0;//register of dividend_sign
        reg   divisor_sign_bit=0;//register of divisor_sign

        assign  dividend_sign = dividend[DIVIDEND_WIDTH-1];// the highest bit is sign bit
        assign  divisor_sign =  divisor[DIVISOR_WIDTH-1];  // the highest bit is sign bit
        assign dividend_unsigned = (dividend_sign)?
                                   ((dividend_sign & (!(|dividend[DIVIDEND_WIDTH-2:0])))?dividend[DIVIDEND_WIDTH-1:0]:{1'b0,((~dividend[DIVIDEND_WIDTH-2:0])+1'b1)}):
                                    dividend[DIVIDEND_WIDTH-1:0]; // Convert dividend to unsigned
        assign divisor_unsigned = (divisor_sign)?
                                   ((divisor_sign & (!(|divisor[DIVISOR_WIDTH-2:0])))?divisor[DIVISOR_WIDTH-1:0]:{1'b0,((~divisor[DIVISOR_WIDTH-2:0])+1'b1)}):
                                    divisor[DIVISOR_WIDTH-2:0];
            
        always@(posedge clk or negedge rstn) begin //update the registers
                if(!rstn) begin
                        dividend_unsigned_r <= {(DIVIDEND_WIDTH){1'b0}};
                        divisor_unsigned_r <= {(DIVISOR_WIDTH) {1'b0}};     
                        dividend_sign_bit <= 1'b0;
                        divisor_sign_bit <= 1'b0;
                    end
                else if (clk_en) begin
                       dividend_unsigned_r <= dividend_unsigned;
                       divisor_unsigned_r <= divisor_unsigned;
                       dividend_sign_bit <= dividend_sign;
                       divisor_sign_bit <= divisor_sign;
                end
                else begin
                       dividend_unsigned_r <= dividend_unsigned_r;
                       divisor_unsigned_r <= divisor_unsigned_r;
                       dividend_sign_bit <= dividend_sign_bit;
                       divisor_sign_bit <= divisor_sign_bit;
                end 
        end

        wire [16:0] reciprocal_shift; // the output of drm, used as multiplier in lutmult algorithm
        wire [DIVIDEND_WIDTH-1:0] quotient_out; // the output of latency
        wire [DIVISOR_WIDTH-1:0] remainder_out; // the output of latency
        wire dividend_sign_bit_out;             // the output of latency
        wire divisor_sign_bit_out;              // the output of latency
        wire [DIVIDEND_WIDTH-1:0] quotient_out_wait; // the output of core
        wire [DIVISOR_WIDTH-1:0] remainder_out_wait; // the output of core
        wire dividend_sign_bit_out_wait;             // the output of core
        wire divisor_sign_bit_out_wait;              // the output of core
        wire dividend_sign_bit_pass;            // the output of drm, keeping the sign bit of original input information, and pass to core
        wire divisor_sign_bit_pass;             // the output of drm, keeping the sign bit of original input information, and pass to core


        ipsxe_divider_lutmult_drm_v1_0 
        #(
            .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
            .SIGNED(SIGNED),
            .DIVISOR_WIDTH(DIVISOR_WIDTH)
        )
        lutmult_drm_m0( //to search the multiplier by divisor, and pass the corresponding dividend and divisor
            .clk(clk),
            .rstn(rstn),
            .clk_en(clk_en),
            .addr_in_signed({divisor_unsigned_r}),
            .dividend_signed({dividend_unsigned_r}),
            .addr_in_unsigned({(DIVISOR_WIDTH){1'b0}}),
            .dividend_unsigned({(DIVIDEND_WIDTH){1'b0}}),
            .Lut_out(reciprocal_shift),
            .dividend_sign_bit_signed(dividend_sign_bit),
            .divisor_sign_bit_signed(divisor_sign_bit),
            .dividend_sign_bit_pass_signed(dividend_sign_bit_pass),
            .divisor_sign_bit_pass_signed(divisor_sign_bit_pass),
            .dividend_out_unsigned(),
            .divisor_out_unsigned(),
            .dividend_out_signed(dividend_pass),
            .divisor_out_signed(divisor_pass)
        );

        if (LATENCY == 2) begin 
            ipsxe_divider_lutmult_core_latency_0_v1_0
            #(
                .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
                .SIGNED(SIGNED),
                .DIVISOR_WIDTH(DIVISOR_WIDTH)
            )
            lutmult_core_m0( //use dividend, divisor, and the corresponding data from drm to calculate the result
                .dividend_signed(dividend_pass),
                .divisor_signed(divisor_pass),
                .dividend_unsigned({(DIVIDEND_WIDTH){1'b0}}),
                .divisor_unsigned({(DIVISOR_WIDTH){1'b0}}),
                .reciprocal_table(reciprocal_shift),
                .quotient_stage5_signed(quotient_out_wait),
                .remainder_stage5_signed(remainder_out_wait),
                .quotient_stage5_unsigned(),
                .remainder_stage5_unsigned(),
                .dividend_sign_bit_out_signed(dividend_sign_bit_out),
                .divisor_sign_bit_out_signed(divisor_sign_bit_out),
                .dividend_sign_bit_pass_signed(dividend_sign_bit_pass),
                .divisor_sign_bit_pass_signed(divisor_sign_bit_pass)
            );
        end else if(LATENCY == 3 || LATENCY == 4 || LATENCY == 5 || LATENCY == 6) begin
            ipsxe_divider_lutmult_core_latency_1_v1_1
            #(
                .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
                .SIGNED(SIGNED),
                .DIVISOR_WIDTH(DIVISOR_WIDTH)
            )
            lutmult_core_m0( //use dividend, divisor, and the corresponding data from drm to calculate the result
                .clk(clk),
                .rstn(rstn),
                .clk_en(clk_en),
                .dividend_signed(dividend_pass),
                .divisor_signed(divisor_pass),
                .dividend_unsigned({(DIVIDEND_WIDTH){1'b0}}),
                .divisor_unsigned({(DIVISOR_WIDTH){1'b0}}),
                .reciprocal_table(reciprocal_shift),
                .quotient_stage5_signed(quotient_out_wait),
                .remainder_stage5_signed(remainder_out_wait),
                .quotient_stage5_unsigned(),
                .remainder_stage5_unsigned(),
                .dividend_sign_bit_out_signed(dividend_sign_bit_out_wait),
                .divisor_sign_bit_out_signed(divisor_sign_bit_out_wait),
                .dividend_sign_bit_pass_signed(dividend_sign_bit_pass),
                .divisor_sign_bit_pass_signed(divisor_sign_bit_pass)
            );
            
            ipsxe_divider_lutmult_latency_v1_0
            #(
                .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
                .SIGNED(SIGNED),
                .LATENCY(BLOCK_LATENCY),
                .DIVISOR_WIDTH(DIVISOR_WIDTH)
            )
            u_lutmult_latency(
                .clk(clk),
                .rstn(rstn),
                .clk_en(clk_en),
                .quotient_stage5_signed_in(quotient_out_wait),
                .remainder_stage5_signed_in(remainder_out_wait),
                .quotient_stage5_unsigned_in({(DIVIDEND_WIDTH){1'b0}}),
                .remainder_stage5_unsigned_in({(DIVISOR_WIDTH){1'b0}}),
                .dividend_sign_bit_in_signed(dividend_sign_bit_out_wait),
                .divisor_sign_bit_in_signed(divisor_sign_bit_out_wait),
                .quotient_stage5_signed_out(quotient_out),
                .remainder_stage5_signed_out(remainder_out),
                .quotient_stage5_unsigned_out(),
                .remainder_stage5_unsigned_out(),
                .dividend_sign_bit_out_signed(dividend_sign_bit_out),
                .divisor_sign_bit_out_signed(divisor_sign_bit_out)
            );        
        end else begin
            ipsxe_divider_lutmult_core_latency_5_v1_0
            #(
                .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
                .SIGNED(SIGNED),
                .DIVISOR_WIDTH(DIVISOR_WIDTH)
            )
            lutmult_core_m0( //use dividend, divisor, and the corresponding data from drm to calculate the result
                .clk(clk),
                .rstn(rstn),
                .clk_en(clk_en),
                .dividend_signed(dividend_pass),
                .divisor_signed(divisor_pass),
                .dividend_unsigned({(DIVIDEND_WIDTH){1'b0}}),
                .divisor_unsigned({(DIVISOR_WIDTH){1'b0}}),
                .reciprocal_table(reciprocal_shift),
                .quotient_stage5_signed(quotient_out_wait),
                .remainder_stage5_signed(remainder_out_wait),
                .quotient_stage5_unsigned(),
                .remainder_stage5_unsigned(),
                .dividend_sign_bit_out_signed(dividend_sign_bit_out_wait),
                .divisor_sign_bit_out_signed(divisor_sign_bit_out_wait),
                .dividend_sign_bit_pass_signed(dividend_sign_bit_pass),
                .divisor_sign_bit_pass_signed(divisor_sign_bit_pass)
            );
                
            ipsxe_divider_lutmult_latency_v1_0
            #(
                .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
                .SIGNED(SIGNED),
                .LATENCY(BLOCK_LATENCY_HIGH),
                .DIVISOR_WIDTH(DIVISOR_WIDTH)
            )
            u_lutmult_latency(
                .clk(clk),
                .rstn(rstn),
                .clk_en(clk_en),
                .quotient_stage5_signed_in(quotient_out_wait),
                .remainder_stage5_signed_in(remainder_out_wait),
                .quotient_stage5_unsigned_in({(DIVIDEND_WIDTH){1'b0}}),
                .remainder_stage5_unsigned_in({(DIVISOR_WIDTH){1'b0}}),
                .dividend_sign_bit_in_signed(dividend_sign_bit_out_wait),
                .divisor_sign_bit_in_signed(divisor_sign_bit_out_wait),
                .quotient_stage5_signed_out(quotient_out),
                .remainder_stage5_signed_out(remainder_out),
                .quotient_stage5_unsigned_out(),
                .remainder_stage5_unsigned_out(),
                .dividend_sign_bit_out_signed(dividend_sign_bit_out),
                .divisor_sign_bit_out_signed(divisor_sign_bit_out)
            );
        end

        //assign the result accroding to the sign bit and the absolute value
        assign quotient = (dividend_sign_bit_out^divisor_sign_bit_out)?
                     ((quotient_out[DIVIDEND_WIDTH-1] & (!(|quotient_out[DIVIDEND_WIDTH-2:0])))?quotient_out:{1'b0,((~quotient_out[DIVIDEND_WIDTH-2:0])+1)}):
                      quotient_out[DIVIDEND_WIDTH-1:0]; 
//                ((&quotient_unsigned)?{{1'b1},{DIVIDEND_WIDTH{1'b0}}}:{{1'b1},((~quotient_unsigned[DIVIDEND_WIDTH-2:0])+1)}):
//                {{1'b0},quotient_unsigned[DIVIDEND_WIDTH-2:0]};
            // For the remainder, if dividend_sign_r is true, assign a 2's complement value of remainder_unsigned
        assign remainder = (dividend_sign_bit_out)?
                     ((remainder_out[DIVISOR_WIDTH-1] & (!(|remainder_out[DIVISOR_WIDTH-2:0])))?remainder_out:{1'b0,((~remainder_out[DIVISOR_WIDTH-2:0])+1)}):
                     remainder_out[DIVISOR_WIDTH-1:0]; 
end
else begin              //A generate if block. Circuit is generated only when SIGNED is 0
        wire [16:0] reciprocal_shift;
        wire [DIVIDEND_WIDTH-1:0] dividend_pass;
        wire [DIVISOR_WIDTH-1:0] divisor_pass;
        wire [DIVIDEND_WIDTH-1:0] quotient_wait;
        wire [DIVISOR_WIDTH-1:0] remainder_wait; 

        ipsxe_divider_lutmult_drm_v1_0 
        #(
            .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
            .SIGNED(SIGNED),
            .DIVISOR_WIDTH(DIVISOR_WIDTH)
        )
        lutmult_drm_m0(//to search the multiplier by divisor, and pass the corresponding dividend and divisor
            .clk(clk),
            .rstn(rstn),
            .clk_en(clk_en),
            .addr_in_unsigned(divisor),
            .dividend_unsigned(dividend),
            .addr_in_signed({(DIVISOR_WIDTH){1'b0}}),
            .dividend_signed({(DIVIDEND_WIDTH){1'b0}}),
            .Lut_out(reciprocal_shift),
            .dividend_sign_bit_signed(1'b0),
            .divisor_sign_bit_signed(1'b0),
            .dividend_sign_bit_pass_signed(),
            .divisor_sign_bit_pass_signed(),
            .dividend_out_signed(),
            .divisor_out_signed(),
            .dividend_out_unsigned(dividend_pass),
            .divisor_out_unsigned(divisor_pass)
        );

        if (LATENCY == 1 || LATENCY == 2 ||LATENCY == 3 ||LATENCY == 4) begin
            ipsxe_divider_lutmult_core_latency_1_v1_1
            #(
                .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
                .SIGNED(SIGNED),
                .DIVISOR_WIDTH(DIVISOR_WIDTH)
            )
            lutmult_core_m0(//use dividend, divisor, and the corresponding data from drm to calculate the result
                .clk(clk),
                .rstn(rstn),
                .clk_en(clk_en),
                .dividend_unsigned(dividend_pass),
                .divisor_unsigned(divisor_pass),
                .dividend_signed({(DIVIDEND_WIDTH){1'b0}}),
                .divisor_signed({(DIVISOR_WIDTH){1'b0}}),
                .reciprocal_table(reciprocal_shift),
                .quotient_stage5_unsigned(quotient_wait),
                .remainder_stage5_unsigned(remainder_wait),
                .quotient_stage5_signed(),
                .remainder_stage5_signed(),
                .dividend_sign_bit_out_signed(),
                .divisor_sign_bit_out_signed(),
                .dividend_sign_bit_pass_signed(1'b0),
                .divisor_sign_bit_pass_signed(1'b0)
            );
            ipsxe_divider_lutmult_latency_v1_0
            #(
                .DIVIDEND_WIDTH(DIVIDEND_WIDTH), 
                .SIGNED(SIGNED),
                .LATENCY(BLOCK_LATENCY),
                .DIVISOR_WIDTH(DIVISOR_WIDTH)
            )
            u_lutmult_latency(
                .clk(clk),
                .rstn(rstn),
                .clk_en(clk_en),
                .quotient_stage5_unsigned_in(quotient_wait),
                .remainder_stage5_unsigned_in(remainder_wait),
                .quotient_stage5_signed_in({(DIVIDEND_WIDTH){1'b0}}),
                .remainder_stage5_signed_in({(DIVISOR_WIDTH){1'b0}}),
                .quotient_stage5_unsigned_out(quotient),
                .remainder_stage5_unsigned_out(remainder),
                .quotient_stage5_signed_out(),
                .remainder_stage5_signed_out(),
                .dividend_sign_bit_in_signed(1'b0),
                .divisor_sign_bit_in_signed(1'b0),
                .dividend_sign_bit_out_signed(),
                .divisor_sign_bit_out_signed()
            );
        end else begin
            ipsxe_divider_lutmult_core_latency_5_v1_0
            #(
                .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
                .SIGNED(SIGNED),
                .DIVISOR_WIDTH(DIVISOR_WIDTH)
            )
            lutmult_core_m0(//use dividend, divisor, and the corresponding data from drm to calculate the result
                .clk(clk),
                .rstn(rstn),
                .clk_en(clk_en),
                .dividend_unsigned(dividend_pass),
                .divisor_unsigned(divisor_pass),
                .dividend_signed({(DIVIDEND_WIDTH){1'b0}}),
                .divisor_signed({(DIVISOR_WIDTH){1'b0}}),
                .reciprocal_table(reciprocal_shift),
                .quotient_stage5_unsigned(quotient_wait),
                .remainder_stage5_unsigned(remainder_wait),
                .quotient_stage5_signed(),
                .remainder_stage5_signed(),
                .dividend_sign_bit_out_signed(),
                .divisor_sign_bit_out_signed(),
                .dividend_sign_bit_pass_signed(1'b0),
                .divisor_sign_bit_pass_signed(1'b0)
            );
            ipsxe_divider_lutmult_latency_v1_0
            #(
                .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
                .SIGNED(SIGNED),
                .LATENCY(BLOCK_LATENCY_HIGH),
                .DIVISOR_WIDTH(DIVISOR_WIDTH)
            )
            u_lutmult_latency(
                .clk(clk),
                .rstn(rstn),
                .clk_en(clk_en),
                .quotient_stage5_unsigned_in(quotient_wait),
                .remainder_stage5_unsigned_in(remainder_wait),
                .quotient_stage5_signed_in({(DIVIDEND_WIDTH){1'b0}}),
                .remainder_stage5_signed_in({(DIVISOR_WIDTH){1'b0}}),
                .quotient_stage5_unsigned_out(quotient),
                .remainder_stage5_unsigned_out(remainder),
                .quotient_stage5_signed_out(),
                .remainder_stage5_signed_out(),
                .dividend_sign_bit_in_signed(1'b0),
                .divisor_sign_bit_in_signed(1'b0),
                .dividend_sign_bit_out_signed(),
                .divisor_sign_bit_out_signed()
            );

        end   
end
endgenerate

endmodule
