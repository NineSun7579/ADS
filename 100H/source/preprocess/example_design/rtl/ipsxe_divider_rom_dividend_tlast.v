module ipsxe_divider_rom_dividend_tlast  
(
    input clk,
    input rstn,
    input [3:0] rd_addr,
    output reg i_axi4s_dividend_tlast = 1'b0
)/* synthesis syn_romstyle = "select_rom" */;

reg  mem [15:0];

integer i;
initial begin
    for (i=0;i<2**4;i=i+1) begin
        mem[i]= 1'b0;
    end
end

always@(posedge clk or negedge rstn)begin
    if(!rstn)begin
        i_axi4s_dividend_tlast <= 0;
    end
    else begin
        i_axi4s_dividend_tlast <= mem[rd_addr];
    end
end
generate
initial begin
mem[0] = 0;
mem[1] =0;
mem[2] =0;
mem[3] =0;
mem[4] =0;
mem[5] =0;
mem[6] =0;
mem[7] =0;
mem[8] =0;
mem[9] =0;
mem[10] =0;
mem[11] =0;
mem[12] =0;
mem[13] =1;
mem[14] =1;
mem[15] =1;
end
endgenerate
endmodule