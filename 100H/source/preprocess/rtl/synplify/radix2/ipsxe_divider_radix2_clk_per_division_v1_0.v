// Module radix2_clk_per_division 
// This module adjusts the clock division ratio according to the CLK_PER_DIVISION parameter
//In this module, radix2_clk_per_division, the clock division ratio is adjusted according to the value of the parameter CLK_PER_DIVISION.
// If the clock division ratio is 1, 2, or 4, the count (cnt) is incremented each time the clock enable signal is high until the count equals to the division ratio minus one. 
//For clock division ratio other than 1, 2, or 4, the count is incremented until it reaches 7. A reset signal will clear the count.
module ipsxe_divider_radix2_clk_per_division_v1_0
#(
    parameter CLK_PER_DIVISION = 2, // Default clock per division is 1
    parameter CNT_WIDTH = 0 // Default count width is 0
)
(   
    input clk, // Input clock signal
    input rst_n, // Input reset signal
    input clk_en, // Input clock enable signal
    output reg [CNT_WIDTH:0] cnt= 0 // Output register for the count
    );

    // The generate block is used to create different always blocks based on CLK_PER_DIVISION parameter
    generate
    if (CLK_PER_DIVISION == 1) begin
        // When CLK_PER_DIVISION equals 1, reset or clock enable will clear the count
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n) begin
                cnt <= 1'b0;
                end
                else if (clk_en)begin
                 cnt <= 1'b0;
            end
        end
    end
    else if(CLK_PER_DIVISION == 2)begin
        // When CLK_PER_DIVISION equals 2, reset will clear the count to 0 and the count will increment with clock enable until it reaches 1 and then it resets
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n) begin
                cnt <= {1'b0};
            end
            else if(clk_en) begin
                if(cnt == 1)begin
                    cnt <= {1'b0};
                end
                else begin
                    cnt <= cnt +1'b1;
                end
            end
        end
    end
    else if(CLK_PER_DIVISION == 4)begin
        // When CLK_PER_DIVISION equals 4, reset will clear the count to 00 and the count will increment with clock enable until it reaches 3 and then it resets
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n) begin
                cnt <= {2{1'b0}};
            end
            else if(clk_en) begin
                if(cnt == 3)begin
                    cnt <= {2{1'b0}};
                end
                else begin
                    cnt <= cnt +1'b1;
                end
            end
        end
    end
    else begin
        // When CLK_PER_DIVISION equals any other value, reset will clear the count to 000 and the count will increment with clock enable until it reaches 7 and then it resets
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n) begin
                cnt <= {3{1'b0}};
            end
            else if(clk_en) begin
                if(cnt == 7)begin
                    cnt <= {3{1'b0}};
                end
                else begin
                    cnt <= cnt +1'b1;
                end
            end
        end
    end
    endgenerate

endmodule
