
module radix2_clk_per_division
#(
    parameter CLK_PER_DIVISION = 1
)
(
    clk,
    rst_n,
    clk_en,
    cnt
    );

    input clk;
    input rst_n;
    input clk_en;


output   reg [2:0]cnt;
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


endmodule
