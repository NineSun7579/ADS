// This module performs radix2 division operations on AXI streams. It supports configurable 
// operand widths and the quotient fractional width.
// Parameters DIVIDEND_WIDTH, DIVISOR_WIDTH, and QUOTIENT_FRACTIONAL_WIDTH are configurable to
// tailor the module to the needs of the application.
module ipsxe_divider_radix2_axi_v1_1   // Module definition for radix-2 division with AXI interface
#(
    // Parameters for the module are defined here.
    parameter DIVIDEND_WIDTH = 8,  // Width of the dividend
    parameter DIVISOR_WIDTH = 8,  // Width of the divisor
    parameter QUOTIENT_FRACTIONAL_WIDTH = 64,  // Width of the fractional part of the quotient
    // Parameters DIVIDEND_TUSER_WIDTH and DIVISOR_TUSER_WIDTH determine the width of the 
    // optional AXI TUSER signals on the dividend and divisor input streams.
    parameter DIVIDEND_TUSER_WIDTH = 1,  // Width of the user-defined attribute for the dividend stream
    parameter DIVISOR_TUSER_WIDTH = 1,  // Width of the user-defined attribute for the divisor stream
    parameter OUTPUT_TLAST = 3,  
    parameter DOUT_TDATA_QUOTIENT_FRACT = 64,
    parameter DOUT_TDATA_QUOTIENT = 64,
    parameter DOUT_TDATA_REMAINDER = 16, 
    parameter Remainder_Type = 0,  // 1 is fraction, 0 is remainder
    parameter M_AXIS_DOUT_TDATA_WIDTH = (Remainder_Type == 0) ? (DOUT_TDATA_QUOTIENT+DOUT_TDATA_REMAINDER) : (DOUT_TDATA_QUOTIENT_FRACT),
    // Parameter CLK_PER_DIVISION determines the number of clock cycles that the division operation takes.
    // The smaller the value, the faster the division operation, but the larger the resource usage.
    parameter CLK_PER_DIVISION = 2,  
    // If the parameter ZERO_DETECT is set to 1, then the divisor zero detection is enabled. 
    parameter ZERO_DETECT =1,
    parameter TUSER_WIDTH = 3,
    parameter DIVIDEND_TUSER = 1,
    parameter DIVISOR_TUSER = 1,
    parameter DIVIDEND_TLAST = 1,
    parameter DIVISOR_TLAST = 1,
    parameter TUSER = 1,
    parameter TLAST = 1,
    parameter OUTPUT_TREADY = 0,
 
    // If ARESETN parameter is set to 1, then reset is active low.
    parameter ARESETN = 1,
    parameter ACLKEN = 1,
    // If SIGNED is set to 1, the operands are treated as signed, otherwise they are unsigned.
    parameter SIGNED = 1,
    parameter BLOCKING = 0,
    parameter LATENCY_MODE = 0,
    parameter LATENCY = 10
)
(
    // Inputs and outputs for the module are defined here.
    input aclk,  // AXI clock signal
    input aresetn,  // Reset signal
    input aclken,  // Clock enable signal
    input  [DIVISOR_TUSER_WIDTH-1:0]s_axis_divisor_tuser,  // User-defined attribute for the divisor stream
    input  s_axis_divisor_tlast,  // Last signal for the divisor stream
    input  [DIVIDEND_TUSER_WIDTH-1:0]s_axis_dividend_tuser,  // User-defined attribute for the dividend stream
    input  s_axis_dividend_tlast,  // Last signal for the dividend stream
    input  [DIVIDEND_WIDTH-1:0]s_axis_dividend_tdata,  // Data for the dividend stream
    input  s_axis_divisor_tvalid,  // Valid signal for the divisor stream
    input  [DIVISOR_WIDTH-1:0]s_axis_divisor_tdata,  // Data for the divisor stream
    input  s_axis_dividend_tvalid,  // Valid signal for the dividend stream

    // The module provides two ready signals, s_axis_divisor_tready and s_axis_dividend_tready, which indicate when the module is ready to accept new inputs.
    output  s_axis_divisor_tready,  // Ready signal for the divisor stream
    output  s_axis_dividend_tready,  // Ready signal for the dividend stream
    // The module provides one valid signal, m_axis_dout_tvalid, which indicates when the output is valid.
    output reg m_axis_dout_tvalid= 0 ,  // Valid signal for the output data stream
    output wire [TUSER_WIDTH-1:0]m_axis_dout_tuser,   
    output reg m_axis_dout_tlast= 0,   

    input  m_axis_dout_tready,
    output reg [(M_AXIS_DOUT_TDATA_WIDTH-1):0]m_axis_dout_tdata= {(M_AXIS_DOUT_TDATA_WIDTH){1'b0}}
    );

// After this are a series of calculations and signal assignments based on the inputs and module parameters.

// Parameters DIVI_ADDQ_WIDTH and AUTO_LATENCY are derived from the other parameters and are used internally by the module.

parameter DIVI_ADDQ_WIDTH = (Remainder_Type == 1) ? 
                          ((DIVISOR_WIDTH >= DIVIDEND_WIDTH) ? (DIVISOR_WIDTH+QUOTIENT_FRACTIONAL_WIDTH) : (DIVIDEND_WIDTH+QUOTIENT_FRACTIONAL_WIDTH)) : 
                          ((DIVISOR_WIDTH >= DIVIDEND_WIDTH) ? (DIVISOR_WIDTH) : (DIVIDEND_WIDTH));

parameter AUTO_LATENCY = (SIGNED==1) ?
                          ((Remainder_Type == 1) ? (DIVIDEND_WIDTH + QUOTIENT_FRACTIONAL_WIDTH + 2) : (DIVIDEND_WIDTH + 3)) :
                          ((Remainder_Type == 1) ? (DIVIDEND_WIDTH + QUOTIENT_FRACTIONAL_WIDTH + 2) : (DIVIDEND_WIDTH + 2));

parameter MANUAL_LATENCY=LATENCY;

parameter LATENCY_AXI = (LATENCY_MODE == 1) ? (MANUAL_LATENCY) : AUTO_LATENCY;

parameter LATENCY_ZERO = (LATENCY_MODE == 1) && (MANUAL_LATENCY <= 2);

parameter ZERO_SIGNED_LATENCY = ((Remainder_Type==1) ? (DIVI_ADDQ_WIDTH -1) : (DIVI_ADDQ_WIDTH)) ;

parameter CNT_WIDTH = (CLK_PER_DIVISION == 8) ? 2 : ((CLK_PER_DIVISION == 4) ? 1 : 0);
    // Defining wire-type variables for different signals
    // Assigning system clock to clk
wire clk;// clk: system clock
wire rst_n;    // rst_n: asynchronous active low reset
wire clk_en;    // clk_en: clock enable
wire dout_tready;
wire dout_tvalid;    // dout_tvalid: indicates the validity of the data output

wire [QUOTIENT_FRACTIONAL_WIDTH-1:0]quotient_fract;    // quotient_fract: fractional part of the quotient from the division operation
wire [DIVISOR_WIDTH-1:0]remainder;    // remainder: remainder from the division operation
wire [DIVIDEND_WIDTH-1:0]quotient;

reg s_axis_divisor_tready_r= 0;
reg s_axis_dividend_tready_r= 0;

assign clk = aclk;
assign rst_n = aresetn;
// Generate block for the conditional assignment of rst_n
// generate
//     if (ARESETN == 1) begin        // If ARESETN is 1, rst_n is assigned aresetn
//         assign rst_n = aresetn;
//     end
//     else begin        // If ARESETN is not 1, rst_n is always high (1'b1)
//         assign rst_n = 1'b1;
//     end
// endgenerate

    // Generate block for the conditional assignment of clk_en
generate
    if (ACLKEN == 1) begin
        // If ACLKEN is 1, clk_en is assigned as the logical AND of aclken and dout_tready
        assign clk_en = aclken && dout_tready;
    end
    else begin
        // If ACLKEN is not 1, clk_en is always assigned dout_tready
        assign clk_en = dout_tready;
    end
endgenerate   

    // Generate block for the conditional assignment of dout_tready
generate
    if (OUTPUT_TREADY == 1) begin
        // If OUTPUT_TREADY is 1, dout_tready is assigned m_axis_dout_tready
        assign dout_tready = m_axis_dout_tready;
    end
    else begin
        // If OUTPUT_TREADY is not 1, dout_tready is always high (1'b1)
        assign dout_tready = 1'b1;
    end
endgenerate

generate
    if(LATENCY_ZERO == 1) begin
        if (SIGNED == 1) begin
        // Signed division
            wire dividend_sign; // Sign bit of the dividend
            wire divisor_sign;  // Sign bit of the diviso

            wire [DIVIDEND_WIDTH-1:0] dividend_unsigned; // Unsigned dividend
            wire [DIVISOR_WIDTH-1:0] divisor_unsigned; // Unsigned divisor
            wire [QUOTIENT_FRACTIONAL_WIDTH-2:0] quotient_fract_unsigned; // Unsigned fractional part of the quotient
            wire [DIVISOR_WIDTH-1:0] remainder_unsigned; // Unsigned remainder
            wire [DIVIDEND_WIDTH-1:0] quotient_unsigned; // Unsigned quotient
          
            assign dividend_sign = s_axis_dividend_tdata[DIVIDEND_WIDTH-1]; // Extract sign bit of the dividend
            assign divisor_sign =  s_axis_divisor_tdata[DIVISOR_WIDTH-1]; // Extract sign bit of the divisor
            assign dividend_unsigned = (dividend_sign)?~s_axis_dividend_tdata+1:s_axis_dividend_tdata;
//                                   ((dividend_sign & (!(|s_axis_dividend_tdata[DIVIDEND_WIDTH-2:0])))?s_axis_dividend_tdata[DIVIDEND_WIDTH-1]:{1'b0,((~s_axis_dividend_tdata[DIVIDEND_WIDTH-2:0])+1)}):
//                                    s_axis_dividend_tdata[DIVIDEND_WIDTH-1:0]; // Convert dividend to unsigned
            assign divisor_unsigned = (divisor_sign)? ~s_axis_divisor_tdata+1:s_axis_divisor_tdata;
//                                   ((divisor_sign & (!(|s_axis_divisor_tdata[DIVISOR_WIDTH-2:0])))?s_axis_divisor_tdata[DIVISOR_WIDTH-1]:{1'b0,((~s_axis_divisor_tdata[DIVISOR_WIDTH-2:0])+1)}):
//                                    s_axis_divisor_tdata[DIVISOR_WIDTH-2:0];
            
//              assign dividend_unsigned = (dividend_sign)?((~dividend[DIVIDEND_WIDTH-2:0])+1):dividend[DIVIDEND_WIDTH-2:0]; // Convert dividend to unsigned
//        assign divisor_unsigned = (divisor_sign)?((~divisor[DIVISOR_WIDTH-2:0])+1):divisor[DIVISOR_WIDTH-2:0]; // Convert divisor to unsigned
            // Clock process for register update
            ipsxe_divider_iteration_zero_latency_v1_0 #(
                .DIVIDEND_W(DIVIDEND_WIDTH),
                .DIVISOR_W(DIVISOR_WIDTH),
                .QUOTIENT_FRACT_W(QUOTIENT_FRACTIONAL_WIDTH-1),
                .Remainder_Type(Remainder_Type),
                .DIVI_ADDQ_W(ZERO_SIGNED_LATENCY)
            ) u_ipsxe_divider_iteration_zero_latency_v1_0 (
                .dividend(dividend_unsigned),
                .divisor(divisor_unsigned),
                .quotient_fract(quotient_fract_unsigned),
                .remainder(remainder_unsigned),
                .quotient(quotient_unsigned)
                );
            if (Remainder_Type == 1) begin
            // Depending on the XOR result of dividend_sign_r and divisor_sign_r, the quotient is assigned a value
                assign quotient = (dividend_sign^divisor_sign)?
                    ((quotient_unsigned[DIVIDEND_WIDTH-1] & (!(|quotient_unsigned[DIVIDEND_WIDTH-2:0])))?quotient_unsigned:{1'b1,((~quotient_unsigned[DIVIDEND_WIDTH-2:0])+1)}):
                // If XOR result is false, assign quotient_unsigned directly
                    {{1'b0},quotient_unsigned[DIVIDEND_WIDTH-2:0]};
                    // If XOR result is true, assign a 2's complement value of quotient_unsigned
                    // {{1'b1},((~quotient_unsigned[DIVIDEND_WIDTH-2:0])+1)}:
                    // // If XOR result is false, assign quotient_unsigned directly
                    // {{1'b0},quotient_unsigned[DIVIDEND_WIDTH-2:0]};
                // Same logic is applied to quotient_fract
                assign quotient_fract = (dividend_sign^divisor_sign)?
                    {{1'b1},((~quotient_fract_unsigned[QUOTIENT_FRACTIONAL_WIDTH-2:0])+1)}:
                    {{1'b0},quotient_fract_unsigned[QUOTIENT_FRACTIONAL_WIDTH-2:0]};
            end
            else begin // If Remainder_Type is not 1, the following code block will execute
                // Similar to the above, depending on the XOR result, the quotient is assigned a value
                assign quotient = (dividend_sign^divisor_sign)?
                     ((quotient_unsigned[DIVIDEND_WIDTH-1] & (!(|quotient_unsigned[DIVIDEND_WIDTH-2:0])))?quotient_unsigned:{1'b1,((~quotient_unsigned[DIVIDEND_WIDTH-2:0])+1)}):
                      quotient_unsigned[DIVIDEND_WIDTH-1:0]; 
//                ((&quotient_unsigned)?{{1'b1},{DIVIDEND_WIDTH{1'b0}}}:{{1'b1},((~quotient_unsigned[DIVIDEND_WIDTH-2:0])+1)}):
//                {{1'b0},quotient_unsigned[DIVIDEND_WIDTH-2:0]};
            // For the remainder, if dividend_sign_r is true, assign a 2's complement value of remainder_unsigned
               assign remainder = (dividend_sign)?
                     ((remainder_unsigned[DIVISOR_WIDTH-1] & (!(|remainder_unsigned[DIVISOR_WIDTH-2:0])))?remainder_unsigned:{1'b1,((~remainder_unsigned[DIVISOR_WIDTH-2:0])+1)}):
                     remainder_unsigned[DIVISOR_WIDTH-1:0]; 
            end
        end
        else begin//unsigned+latency zero
            ipsxe_divider_iteration_zero_latency_v1_0 #(
                .DIVIDEND_W(DIVIDEND_WIDTH),
                .DIVISOR_W(DIVISOR_WIDTH),
                .QUOTIENT_FRACT_W(QUOTIENT_FRACTIONAL_WIDTH),
                .Remainder_Type(Remainder_Type),
                .DIVI_ADDQ_W(DIVI_ADDQ_WIDTH)
            ) u_ipsxe_divider_iteration_zero_latency_v1_0 (
                .dividend(s_axis_dividend_tdata[DIVIDEND_WIDTH-1:0]),
                .divisor(s_axis_divisor_tdata[DIVISOR_WIDTH-1:0]),
                .quotient_fract(quotient_fract),
                .remainder(remainder),
                .quotient(quotient)
                );
        end
    end
endgenerate


wire m_axis_dout_tvalid_r;
//reg fir_en = 1'b0;
//always @(posedge clk or negedge rst_n) begin
//    if (!rst_n) begin
//        fir_en <= 1'b0;
//    end else if (m_axis_dout_tvalid) begin
//        fir_en <= 1'b1;
//    end
//end
//wire fir_en_r;
//assign fir_en_r = !fir_en && !m_axis_dout_tvalid_r;


generate       
    if(LATENCY_ZERO==1)begin 
        if(MANUAL_LATENCY==0)begin
            always @(*) begin
            // Checking the Remainder_Type parameter
                if (Remainder_Type == 1) begin
                // Always block triggered by positive edge of clk or negative edge of rst_n
                   // m_axis_dout_tdata = (fir_en_r)? {(M_AXIS_DOUT_TDATA_WIDTH){1'b0}}:{{(M_AXIS_DOUT_TDATA_WIDTH-QUOTIENT_FRACTIONAL_WIDTH-DIVIDEND_WIDTH){1'b0}},quotient, quotient_fract};
                    // m_axis_dout_tdata = {{(M_AXIS_DOUT_TDATA_WIDTH-QUOTIENT_FRACTIONAL_WIDTH-DIVIDEND_WIDTH){1'b0}},quotient, quotient_fract};
                    m_axis_dout_tdata = {{(M_AXIS_DOUT_TDATA_WIDTH-QUOTIENT_FRACTIONAL_WIDTH-DIVIDEND_WIDTH){quotient[DIVIDEND_WIDTH-1]}},quotient, quotient_fract};
  
                end
                else begin
                // When Remainder_Type is not 1
                m_axis_dout_tdata = {{(M_AXIS_DOUT_TDATA_WIDTH-QUOTIENT_FRACTIONAL_WIDTH-DIVIDEND_WIDTH){quotient[DIVIDEND_WIDTH-1]}},quotient, remainder};
//                    m_axis_dout_tdata = (fir_en_r)? {(M_AXIS_DOUT_TDATA_WIDTH){1'b0}}:{{(DOUT_TDATA_QUOTIENT-DIVIDEND_WIDTH){1'b0}}, quotient, {(DOUT_TDATA_REMAINDER-DIVISOR_WIDTH){1'b0}}, remainder};
                    // m_axis_dout_tdata = {{(DOUT_TDATA_QUOTIENT-DIVIDEND_WIDTH){1'b0}}, quotient, {(DOUT_TDATA_REMAINDER-DIVISOR_WIDTH){1'b0}}, remainder};
                end
            end
        end
        else begin
            if(MANUAL_LATENCY==1)begin
            // Always block triggered by positive edge of clk or negative edge of rst_n
                always @(posedge clk or negedge rst_n) begin
                    // If reset is active (low)
                    if (!rst_n ) begin
                        // Zeroing out the m_axis_dout_tdata
                        m_axis_dout_tdata <= {(M_AXIS_DOUT_TDATA_WIDTH){1'b0}};
                    end 
//                    else if( fir_en_r)begin
//                        m_axis_dout_tdata <= {(M_AXIS_DOUT_TDATA_WIDTH){1'b0}};
//                        end                      
                    // If clk_en is active
                    else if (clk_en) begin
                        if (Remainder_Type == 1) begin
                        // Assign quotient and fractional part of the quotient to m_axis_dout_tdata
                            m_axis_dout_tdata <= {{(M_AXIS_DOUT_TDATA_WIDTH-QUOTIENT_FRACTIONAL_WIDTH-DIVIDEND_WIDTH){quotient[DIVIDEND_WIDTH-1]}},quotient, quotient_fract};
                        end
                        else begin
                            //m_axis_dout_tdata <= {{(M_AXIS_DOUT_TDATA_WIDTH-QUOTIENT_FRACTIONAL_WIDTH-DIVIDEND_WIDTH){quotient[DIVIDEND_WIDTH-1]}}, quotient, {(DOUT_TDATA_REMAINDER-DIVISOR_WIDTH){1'b0}}, remainder};
                            m_axis_dout_tdata <= {{((M_AXIS_DOUT_TDATA_WIDTH - QUOTIENT_FRACTIONAL_WIDTH - DIVIDEND_WIDTH) > 0 ? (M_AXIS_DOUT_TDATA_WIDTH - QUOTIENT_FRACTIONAL_WIDTH - DIVIDEND_WIDTH) : 0){quotient[DIVIDEND_WIDTH-1]}}, quotient, {(DOUT_TDATA_REMAINDER - DIVISOR_WIDTH > 0 ? (DOUT_TDATA_REMAINDER - DIVISOR_WIDTH) : 0){1'b0}}, remainder};
                        end
                    end
                end
            end
            else begin
               
                    reg [M_AXIS_DOUT_TDATA_WIDTH-1:0]data_r= {(M_AXIS_DOUT_TDATA_WIDTH){1'b0}};
            // Always block triggered by positive edge of clk or negative edge of rst_n
                    always @(posedge clk or negedge rst_n) begin
                    // If reset is active (low)
                        if (!rst_n) begin
                            // Zeroing out the m_axis_dout_tdata
                            m_axis_dout_tdata <= {(M_AXIS_DOUT_TDATA_WIDTH){1'b0}};
                            data_r <= {(M_AXIS_DOUT_TDATA_WIDTH){1'b0}};
                        end 
//                        else 
//                        if( fir_en_r)begin
//                            m_axis_dout_tdata <= {(M_AXIS_DOUT_TDATA_WIDTH){1'b0}};
//                            data_r <= {(M_AXIS_DOUT_TDATA_WIDTH){1'b0}};  
//                            end                      
                        
                        // If clk_en is active
                        else if (clk_en) begin
                            if (Remainder_Type == 1) begin
                            // Assign quotient and fractional part of the quotient to m_axis_dout_tdata
                                data_r <= {{(M_AXIS_DOUT_TDATA_WIDTH-QUOTIENT_FRACTIONAL_WIDTH-DIVIDEND_WIDTH){quotient[DIVIDEND_WIDTH-1]}},quotient, quotient_fract};
                            end
                            else begin
                                data_r <= {{(M_AXIS_DOUT_TDATA_WIDTH-QUOTIENT_FRACTIONAL_WIDTH-DIVIDEND_WIDTH){quotient[DIVIDEND_WIDTH-1]}}, quotient, {(DOUT_TDATA_REMAINDER-DIVISOR_WIDTH){1'b0}}, remainder};
                            end 
                            m_axis_dout_tdata <= data_r;
                        
                    end
                end
            end
        end
    end
endgenerate





// dout_tready: indicates the readiness of the data output
wire [CNT_WIDTH:0] cnt;    // cnt: counter used in the module             
//m_axis_dout_tdata is a register for output data. Its contents are conditioned on the value of the Remainder_Type parameter.
// If Remainder_Type is 1, the output data is the quotient and the fractional part of the quotient. 
//If Remainder_Type is not 1, the output data is the quotient and the remainder. In both cases, the data is padded with zeroes to match the desired width. 
generate
    if(LATENCY_ZERO==0)begin
    // Checking the Remainder_Type parameter
//        always @(* ) begin
    always @(posedge clk or negedge rst_n) begin
              //If reset is active (low)
             if (!rst_n ) begin
                 // Zeroing out the m_axis_dout_tdata
                 m_axis_dout_tdata <= {(M_AXIS_DOUT_TDATA_WIDTH){1'b0}};
             end 
//             else 
//             if(fir_en_r)begin
//                 m_axis_dout_tdata = {(M_AXIS_DOUT_TDATA_WIDTH){1'b0}};
//             end                
             // If clk_en is active
             else if (clk_en) begin
                 if (Remainder_Type == 1) begin
                 // Assign quotient and fractional part of the quotient to m_axis_dout_tdata
                     if(M_AXIS_DOUT_TDATA_WIDTH-QUOTIENT_FRACTIONAL_WIDTH-DIVIDEND_WIDTH == 0)begin
                         m_axis_dout_tdata <= {quotient, quotient_fract};
                     end
                     else begin
                         m_axis_dout_tdata <= {{(M_AXIS_DOUT_TDATA_WIDTH-QUOTIENT_FRACTIONAL_WIDTH-DIVIDEND_WIDTH){quotient[DIVIDEND_WIDTH-1]}},quotient, quotient_fract};
                     end
                 end
                 else begin
                     if(DOUT_TDATA_QUOTIENT - DIVIDEND_WIDTH == 0)begin
                         if(DOUT_TDATA_REMAINDER - DIVISOR_WIDTH == 0) begin
                             m_axis_dout_tdata <= {quotient, remainder};
                         end
                         else begin
                             m_axis_dout_tdata <= {quotient,{(DOUT_TDATA_REMAINDER-DIVISOR_WIDTH){1'b0}}, remainder};
                         end
                     end 
                     else begin
                         if(DOUT_TDATA_REMAINDER - DIVISOR_WIDTH == 0) begin
                             m_axis_dout_tdata <= {{(DOUT_TDATA_QUOTIENT-DIVIDEND_WIDTH){1'b0}}, quotient, remainder};
                         end
                         else begin
                             m_axis_dout_tdata <= {{(DOUT_TDATA_QUOTIENT-DIVIDEND_WIDTH){quotient[DIVIDEND_WIDTH-1]}}, quotient, {(DOUT_TDATA_REMAINDER-DIVISOR_WIDTH){1'b0}}, remainder};
                         end
                     end                    
                 end
             end
             else begin
                m_axis_dout_tdata <= m_axis_dout_tdata;
             end
         end
    end
endgenerate

//********************************************************************************************
//                                          TUSER
//********************************************************************************************
// the radix2_tuser module is created if the TUSER parameter is set. 
//This module may perform certain user-defined operations, as suggested by the name TUSER. 
//The module is instantiated with a set of predefined parameters and connected with the appropriate inputs and outputs.
// Notably, a wire divisor_by_zero is declared to detect if division by zero has occurred, which is enabled when ZERO_DETECT parameter is set.
generate 
    if (TUSER == 1) begin
        if(LATENCY_ZERO==1)begin
            wire [TUSER_WIDTH-1:0]tuser_r;

            if (DIVIDEND_TUSER == 1) begin
                assign tuser_r[TUSER_WIDTH-1:TUSER_WIDTH-DIVIDEND_TUSER_WIDTH] = s_axis_dividend_tuser;
            end
            // When DIVISOR_TUSER is 1, assign part of dout_tuser to divisor_tuser
            if (DIVISOR_TUSER == 1) begin
               assign  tuser_r[TUSER_WIDTH-DIVIDEND_TUSER_WIDTH-1:TUSER_WIDTH-DIVIDEND_TUSER_WIDTH-DIVISOR_TUSER_WIDTH] = s_axis_divisor_tuser;  // User-defined attribute for the divisor stream
            end
            // When ZERO_DETECT is 1, assign least significant bit of dout_tuser to divisor_by_zero
            if (ZERO_DETECT == 1) begin
                assign tuser_r[0] = (s_axis_divisor_tdata == 0)? 1'b1 : 1'b0;
            end

            if(MANUAL_LATENCY==0)begin
                assign m_axis_dout_tuser=tuser_r;
            end
            else begin
                if(MANUAL_LATENCY==1)begin
                    ipsxe_divider_register_nx_v1_0 #(.A_WIDTH(TUSER_WIDTH), 
                     .B_WIDTH(1),
                     .LATENCY(1'b1)
                     )u_ipsxe_divider_register_nx_v1_0 (
                    .clk(clk), 
                    .rst_n(rst_n), 
                    .clk_en(clk_en),
                    .adata(tuser_r),
                    .bdata(),
                    .adata_latency(m_axis_dout_tuser),
                    .bdata_latency()
                    );
                end
                else begin
                    ipsxe_divider_register_nx_v1_0 #(.A_WIDTH(TUSER_WIDTH), 
                     .B_WIDTH(1),
                     .LATENCY(LATENCY_AXI)
                     )u_ipsxe_divider_register_nx_v1_0 (
                    .clk(clk), 
                    .rst_n(rst_n), 
                    .clk_en(clk_en),
                    .adata(tuser_r),
                    .bdata(),
                    .adata_latency(m_axis_dout_tuser),
                    .bdata_latency()
                    );
                end
            end
        end
        else begin
             wire divisor_by_zero; 
             if (ZERO_DETECT == 1) begin
                 assign divisor_by_zero = (s_axis_divisor_tdata == 0)? 1'b1 : 1'b0;
             end
             ipsxe_divider_radix2_tuser_v1_0  
             #(
                 .LATENCY(LATENCY_AXI),
                 .TUSER_WIDTH(TUSER_WIDTH),
                 .DIVIDEND_TUSER(DIVIDEND_TUSER),
                 .DIVISOR_TUSER(DIVISOR_TUSER),
                 .ZERO_DETECT(ZERO_DETECT),
                 .DIVIDEND_TUSER_WIDTH(DIVIDEND_TUSER_WIDTH),
                 .DIVISOR_TUSER_WIDTH(DIVISOR_TUSER_WIDTH)
             )
             u_ipsxe_divider_radix2_tuser_v1_0(
                 .clk(clk),               
                 .rst_n(rst_n),             
                 .clk_en(clk_en),
                 .dividend_tuser(s_axis_dividend_tuser),
                 .divisor_tuser(s_axis_divisor_tuser),
                 .divisor_by_zero(divisor_by_zero),
                 .m_axis_dout_tuser(m_axis_dout_tuser)
             );
        end
    end
endgenerate

//********************************************************************************************
//                                          DOUT_TVALID
//********************************************************************************************
//  Use a shift register to generate the dout_tvalid_itr signal with the latency specified by AUTO_LATENCY.
// The dout_tvalid signal is a logical AND of the tready and tvalid signals from both the divisor and dividend. 
//The shift register ensures the pipeline latency while keeping the synchronous design. 
//The m_axis_dout_tvalid signal is updated at every clock cycle when the clk_en signal is high, with the most significant bit of the dout_tvalid_itr register.  
assign dout_tvalid = (s_axis_dividend_tready) && (s_axis_divisor_tready) && (s_axis_dividend_tvalid) && (s_axis_divisor_tvalid)&&clk_en;


generate
    if(LATENCY_ZERO==1)begin
        if(MANUAL_LATENCY==0)begin
           always @(*) begin
                m_axis_dout_tvalid = dout_tvalid;
            end
        end 
        else begin
            if(MANUAL_LATENCY==1)begin
                always@(posedge clk or negedge rst_n)begin
                    if(!rst_n) begin
                        m_axis_dout_tvalid <= 1'b0;
                    end 
                    else if(clk_en) begin  
                        m_axis_dout_tvalid <= dout_tvalid;
                    end
                end
            end
            else begin
                reg tvalid_r= 0;

                always@(posedge clk or negedge rst_n)begin
                    if(!rst_n) begin
                        m_axis_dout_tvalid <= 1'b0;
                        tvalid_r <= 1'b0;
                    end 
                    else if(clk_en) begin  
                        m_axis_dout_tvalid <= tvalid_r;
                        tvalid_r <= dout_tvalid;
                    end
                end

//                reg [LATENCY_AXI-1:0]s_axis_tvalid_in_r = 0 ;
            	
//            	always@(posedge clk or negedge rst_n)begin
//            	       if (~rst_n)begin
//            	           s_axis_tvalid_in_r <= 'd0;
//            	       end
//            	       else if(clk_en)begin
//            	           s_axis_tvalid_in_r <= s_axis_tvalid_in_r <<1;	    
//            	           s_axis_tvalid_in_r[0] <= dout_tvalid;
//            	       end
//            	       else begin 
//            	           s_axis_tvalid_in_r <= s_axis_tvalid_in_r;
//            	      end	           
//                end	   
            end
        end
    end
    else begin //LATENCY != 0 
    // always @(*) begin
    //     m_axis_dout_tvalid = m_axis_dout_tvalid_r && clk_en;
    // end
    
    	reg [LATENCY_AXI-1:0]s_axis_tvalid_in_r = {LATENCY_AXI{1'b0}} ;
	
	always@(posedge clk or negedge rst_n)begin
	       if (~rst_n)begin
	           s_axis_tvalid_in_r <= 'd0;
	       end
	       else if(clk_en)begin
                  s_axis_tvalid_in_r <= {s_axis_tvalid_in_r[LATENCY_AXI-2:0],dout_tvalid};	    
	        //    s_axis_tvalid_in_r <= s_axis_tvalid_in_r <<1;	    
	        //    s_axis_tvalid_in_r[0] <= dout_tvalid;
	       end
	       else begin 
	           s_axis_tvalid_in_r <= s_axis_tvalid_in_r;
	      end	           
    end	       
	           
    assign m_axis_dout_tvalid_r = s_axis_tvalid_in_r[LATENCY_AXI-1];
//    ipsxe_divider_radix2_distributed_shiftregister_wrapper_v1_3  #(
//    	.FIXED_DEPTH(LATENCY_AXI),
//    	.DATA_WIDTH(1)
//    ) u_ipm_distributed_shiftregister_wrapper_v1_3 (
//    	.din(dout_tvalid),
//    	.clk(clk),
//    	.i_aclken(clk_en),
//    	.rst(!rst_n),
//    	.dout(m_axis_dout_tvalid_r)
//    );
    
     always@(*)begin
         m_axis_dout_tvalid = m_axis_dout_tvalid_r && clk_en;
         end
//    always@(posedge clk or negedge rst_n)begin
//        if(!rst_n) begin
//            m_axis_dout_tvalid <= 1'b0;
//        end 
//        else  begin
//            m_axis_dout_tvalid <= m_axis_dout_tvalid_r && clk_en;
//        end

//        reg  [LATENCY_AXI-1:0] dout_tvalid_itr; 
                    
//        always@(posedge clk or negedge rst_n)begin
//            if(!rst_n) begin
//                dout_tvalid_itr <= {LATENCY_AXI{1'b0}}; 
//                m_axis_dout_tvalid <= 1'b0;
//            end 
//            else if(clk_en) begin  
//                dout_tvalid_itr[0] <= dout_tvalid;
//                dout_tvalid_itr[LATENCY_AXI-1:1] <= dout_tvalid_itr[LATENCY_AXI-2:0];
//                m_axis_dout_tvalid <= dout_tvalid_itr[LATENCY_AXI-1];
//            end
//            else begin
//                dout_tvalid_itr <= {LATENCY_AXI{1'b0}}; 
//                m_axis_dout_tvalid <= 1'b0;
//            end
//    end
    end
endgenerate
//********************************************************************************************
//                                          DIN_TREADY
//********************************************************************************************
//This code section updates the ready flags for the dividend and divisor (s_axis_dividend_tready and s_axis_divisor_tready) based on the clock enable and the counter value.
// It ensures that the ready signals are set high only when the counter reaches the value (CLK_PER_DIVISION - 1), meaning that the appropriate number of clock cycles has passed, and the data is ready for processing. 
//Otherwise, the ready flags are set to 0, indicating that the data is not yet ready.
generate
    if(LATENCY_ZERO==1 || CLK_PER_DIVISION == 1)begin
        // always@(posedge clk or negedge rst_n)begin
        //     if(!rst_n) begin
        //         s_axis_dividend_tready_r <= 1'b0;
        //         s_axis_divisor_tready_r  <= 1'b0;
        //     end
        //     else if(clk_en) begin
        //             s_axis_dividend_tready_r <= 1'b1;
        //             s_axis_divisor_tready_r  <= 1'b1;
        //         end
        //         else begin
        //             s_axis_dividend_tready_r <= 1'b0;
        //             s_axis_divisor_tready_r  <= 1'b0;
        //     end

        assign s_axis_dividend_tready = 1'b1;
        assign s_axis_divisor_tready  = 1'b1;

    end
    else begin

        assign s_axis_dividend_tready=s_axis_dividend_tready_r;
        assign s_axis_divisor_tready=s_axis_divisor_tready_r;
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n) begin
                s_axis_dividend_tready_r <= 1'b0;
                s_axis_divisor_tready_r  <= 1'b0;
            end
            else if(clk_en) begin
                if(cnt == CLK_PER_DIVISION-1'b1)begin
                    s_axis_dividend_tready_r <= 1'b1;
                    s_axis_divisor_tready_r  <= 1'b1;
                end
                else begin
                    s_axis_dividend_tready_r <= 1'b0;
                    s_axis_divisor_tready_r  <= 1'b0;
                end
            end
            else begin
                s_axis_dividend_tready_r <= s_axis_dividend_tready_r;
                s_axis_divisor_tready_r  <= s_axis_divisor_tready_r;
            end
        end
    end
endgenerate
//********************************************************************************************
//                                          IP_CODE
//********************************************************************************************
generate
    if(LATENCY_ZERO==0)begin 
        ipsxe_divider_radix2_clk_per_division_v1_0
        #(.CLK_PER_DIVISION(CLK_PER_DIVISION),
        .CNT_WIDTH(CNT_WIDTH)
        )
        u_ipsxe_divider_radix2_clk_per_division_v1_0(
            .clk(clk),
            .rst_n(rst_n),
            .clk_en(clk_en),
            .cnt(cnt)
        );
        
        ipsxe_divider_radix2_v1_0 #(
            .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
            .DIVISOR_WIDTH(DIVISOR_WIDTH),
            .QUOTIENT_FRACTIONAL_WIDTH(QUOTIENT_FRACTIONAL_WIDTH),
            .CLK_PER_DIVISION(CLK_PER_DIVISION),
            .CNT_WIDTH(CNT_WIDTH),
            .SIGNED(SIGNED),
            .Remainder_Type(Remainder_Type),
            .DIVI_ADDQ_WIDTH(DIVI_ADDQ_WIDTH),
            .LATENCY_MODE( LATENCY_MODE),
            .MANUAL_LATENCY(LATENCY_AXI-1)
        ) u_ipsxe_divider_radix2_v1_0 (
            .clk(clk),
            .rst_n(rst_n),
            .clk_en(clk_en),
            .dividend(s_axis_dividend_tdata[DIVIDEND_WIDTH-1:0]),
            .divisor(s_axis_divisor_tdata[DIVISOR_WIDTH-1:0]),
            .cnt(cnt),
            .quotient_fract(quotient_fract),
            .remainder(remainder),
            .quotient(quotient)
            );
    end
endgenerate
    
//********************************************************************************************
//                                          TLAST
//********************************************************************************************
//If TLAST is 1, a mechanism is created for handling the last transaction in a burst of data, 
//m_axis_dout_tlast, which is derived from either the divisor's tlast, the dividend's tlast, or both, depending on the value of OUTPUT_TLAST. 
//Also, dout_tlast_r is a shift register that delays the assertion of m_axis_dout_tlast by AUTO_LATENCY clock cycles. This delay is applied to ensure that the last valid data item has a corresponding tlast signal.
generate
    if (TLAST == 1) begin
        reg  dout_tlast= 0;
        
        always@(*)
            begin
            case(OUTPUT_TLAST)
            3'b010   :   dout_tlast = s_axis_dividend_tlast;
            3'b001   :   dout_tlast = s_axis_divisor_tlast;
            3'b000   :   dout_tlast = (s_axis_divisor_tlast)||(s_axis_dividend_tlast);
            3'b011   :   dout_tlast = (s_axis_divisor_tlast)&&(s_axis_dividend_tlast);
            default :   dout_tlast = 1'b0;
            endcase
        end 

        if(LATENCY_ZERO==1)begin
            if(MANUAL_LATENCY==0)begin
                always @(*) begin
                    m_axis_dout_tlast = dout_tlast;
                end
            end
            else begin
                if(MANUAL_LATENCY==1)begin
                    always@(posedge clk or negedge rst_n)
                        if(!rst_n) begin
                            m_axis_dout_tlast <= 1'b0;
                        end
                        else if(clk_en) begin 
                            m_axis_dout_tlast <= dout_tlast;
                        end 
                end
                else begin
                    reg tlast_r= 0;
                    always@(posedge clk or negedge rst_n)
                        if(!rst_n) begin
                            m_axis_dout_tlast <= 1'b0;
                            tlast_r <= 1'b0;
                        end
                        else if(clk_en) begin 
                            m_axis_dout_tlast <= tlast_r;
                            tlast_r <= dout_tlast;
                        end 
                end
            end
        end
        else begin
            reg  [AUTO_LATENCY-1:0] dout_tlast_r= {AUTO_LATENCY{1'b0}};
            always@(posedge clk or negedge rst_n)
                if(!rst_n) begin
                    dout_tlast_r <= {LATENCY_AXI{1'b0}};
                    m_axis_dout_tlast <= 1'b0;

                end
                else if(clk_en) begin 
                    dout_tlast_r[0] <= dout_tlast;
                    dout_tlast_r[LATENCY_AXI-1:1] <= dout_tlast_r[LATENCY_AXI-2:0];
                    m_axis_dout_tlast <= dout_tlast_r[LATENCY_AXI-1];
                end 
        end    
    end
endgenerate
        
endmodule