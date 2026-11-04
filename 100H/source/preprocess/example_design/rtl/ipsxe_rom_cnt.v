module ipsxe_rom_cnt (
    input clk,
    input rst_n,
    output reg [3:0] period_cnt = {4{1'd0}}
);

parameter PERIOD = 20;

reg     [4:0]   clk_cnt = {5{1'd0}};


always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        clk_cnt <= 0;
    end
    else begin
        if(clk_cnt == PERIOD) begin
            clk_cnt <= 0;
        end
        else begin
            clk_cnt <= clk_cnt + 5'd1;
        end
    end
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        period_cnt <= 4'b0;
    end
    else begin
        if(clk_cnt == PERIOD) begin
            if (period_cnt == 4'd15) begin
                period_cnt <= 4'd0;
            end
            else begin
                period_cnt <= period_cnt + 1;
            end
        end
        else begin
            period_cnt <= period_cnt;
        end
    end
end

endmodule
