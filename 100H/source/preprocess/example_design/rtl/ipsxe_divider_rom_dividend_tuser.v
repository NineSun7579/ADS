module ipsxe_divider_rom_dividend_tuser #(
    parameter DIVIDEND_TUSER_WIDTH = 8
) (
    input clk,
    input rstn,
    input [3:0] rd_addr,
    output reg [DIVIDEND_TUSER_WIDTH-1:0] i_axi4s_dividend_tuser = {DIVIDEND_TUSER_WIDTH{1'b0}}
)/* synthesis syn_romstyle = "select_rom" */;

reg [DIVIDEND_TUSER_WIDTH-1:0] mem [15:0];

integer i;
initial begin
    for (i=0;i<2**4;i=i+1) begin
        mem[i]= {DIVIDEND_TUSER_WIDTH{1'b0}};
    end
end

always@(posedge clk or negedge rstn)begin
    if(!rstn)begin
        i_axi4s_dividend_tuser <= 0;
    end
    else begin
        i_axi4s_dividend_tuser <= mem[rd_addr];
    end
end
generate
initial begin
mem[0] = 'd0;
mem[1] = 'd20;
mem[2] = 'd0;
mem[3] = 'd15;
mem[4] = 'd24;
mem[5] = 'd123;
mem[6] = 'd123;
mem[7] = 'd123;
mem[8] = 'd123;
mem[9] = 'd67;
mem[10] = 'd67;
mem[11] = 'd67;
mem[12] = 'd67;
mem[13] = 'd147;
mem[14] = 'd147;
mem[15] = 'd147;
end
endgenerate

endmodule