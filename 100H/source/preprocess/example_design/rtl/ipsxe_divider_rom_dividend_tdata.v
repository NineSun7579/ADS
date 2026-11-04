module ipsxe_divider_rom_dividend_tdata #(
    parameter DIVIDEND_WIDTH = 8
) (
    input clk,
    input rstn,
    input [3:0] rd_addr,
    output reg [DIVIDEND_WIDTH-1:0] i_axi4s_dividend_tdata = {DIVIDEND_WIDTH{1'b0}}
)/* synthesis syn_romstyle = "select_rom" */;

reg [DIVIDEND_WIDTH-1:0] mem [15:0];

integer i;
initial begin
    for (i=0;i<2**4;i=i+1) begin
        mem[i]= {DIVIDEND_WIDTH{1'b0}};
    end
end

always@(posedge clk or negedge rstn)begin
    if(!rstn)begin
        i_axi4s_dividend_tdata <= 0;
    end
    else begin
        i_axi4s_dividend_tdata <= mem[rd_addr];
    end
end
generate
initial begin
mem[0] = 0;
mem[1] =49;
mem[2] =0;
mem[3] =116;
mem[4] =50;
mem[5] =100;
mem[6] =50;
mem[7] =50;
mem[8] =50;
mem[9] =80;
mem[10] =80;
mem[11] =80;
mem[12] =80;
mem[13] =127;
mem[14] =127;
mem[15] =127;
end
endgenerate
endmodule