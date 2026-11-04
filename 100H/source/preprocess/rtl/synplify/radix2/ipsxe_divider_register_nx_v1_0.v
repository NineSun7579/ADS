// Module radix2_tuser
// This module generates tuser signals based on the parameters provided. The tuser signals are generated for the dividend, divisor, and the zero detection.
module ipsxe_divider_register_nx_v1_0
#(
    parameter A_WIDTH = 2, // Auto latency parameter
    parameter B_WIDTH = 2, // Width of the tuser signal
    parameter LATENCY = 3 // Flag to decide if tuser for dividend is required
)
( 
    input clk, // Input clock signal
    input rst_n, // Input reset signal
    input clk_en, // Input clock enable signal
    input [A_WIDTH-1:0] adata, // Input tuser signal for dividend
    input [B_WIDTH-1:0] bdata, // Input tuser signal for divisor
    output reg [A_WIDTH-1:0] adata_latency= {A_WIDTH{1'b0}}, // Input tuser signal for dividend
    output reg [B_WIDTH-1:0] bdata_latency= {B_WIDTH{1'b0}}  // Input signal for zero divisor
    
);

// The generate block is used to create assign statements for tuser signals for dividend and divisor based on parameters
generate
    if (LATENCY == 1) begin
        always@(posedge clk or negedge rst_n)begin
    // On reset, clear dout_tuser_itr and m_axis_dout_tuser
            if(!rst_n) begin
               adata_latency <= {A_WIDTH{1'b0}}; //Input tuser signal for dividend
               bdata_latency <= {B_WIDTH{1'b0}}; // Input signal for zero divisor
            end
            // On clock enable, update dout_tuser_itr and m_axis_dout_tuser with dout_tuser
            else if(clk_en) begin
               adata_latency <= adata; //Input tuser signal for dividend
               bdata_latency <= bdata; // Input signal for zero divisor
            end
        end
    end
    else begin
        reg  [A_WIDTH*(LATENCY-1)-1:0] adata_r= {A_WIDTH*(LATENCY-1){1'b0}};
        reg  [B_WIDTH*(LATENCY-1)-1:0] bdata_r= {B_WIDTH*(LATENCY-1){1'b0}};
        always@(posedge clk or negedge rst_n)begin
    // On reset, clear dout_tuser_itr and m_axis_dout_tuser
            if(!rst_n) begin
               adata_latency <= {A_WIDTH{1'b0}}; //Input tuser signal for dividend
               bdata_latency <= {B_WIDTH{1'b0}}; // Input signal for zero divisor
               adata_r <= {(A_WIDTH*(LATENCY-1)){1'b0}}; //Input tuser signal for dividend
               bdata_r <= {(B_WIDTH*(LATENCY-1)){1'b0}}; // Input signal for zero divisor
            end
            // On clock enable, update dout_tuser_itr and m_axis_dout_tuser with dout_tuser
            else if(clk_en) begin
                if(LATENCY==2)begin
                    adata_latency[A_WIDTH-1:0] <= adata_r[A_WIDTH-1:0]; //Input tuser signal for dividend
                    bdata_latency[B_WIDTH-1:0] <= bdata_r[B_WIDTH-1:0]; // Input signal for zero divisor
                    adata_r[A_WIDTH-1:0] <= adata; //Input tuser signal for dividend
                    bdata_r[B_WIDTH-1:0] <= bdata; // Input signal for zero divisor
                end
                else begin
                    adata_latency[A_WIDTH-1:0] <= adata_r[A_WIDTH*(LATENCY-1)-1:A_WIDTH*(LATENCY-2)];
                    bdata_latency[B_WIDTH-1:0] <= bdata_r[B_WIDTH*(LATENCY-1)-1:B_WIDTH*(LATENCY-2)];
                    adata_r[A_WIDTH*(LATENCY-1)-1:A_WIDTH] <= adata_r[A_WIDTH*(LATENCY-2)-1:0];
                    bdata_r[B_WIDTH*(LATENCY-1)-1:B_WIDTH] <= bdata_r[B_WIDTH*(LATENCY-2)-1:0];
                    adata_r[A_WIDTH-1:0] <= adata; //Input tuser signal for dividend
                    bdata_r[B_WIDTH-1:0] <= bdata; // Input signal for zero divisor
                end
            end
        end
    end 
endgenerate

endmodule
