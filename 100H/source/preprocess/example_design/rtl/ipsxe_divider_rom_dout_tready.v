module ipsxe_divider_rom_dout_tready
(
    input clk,
    input rstn,
    input [3:0] rd_addr,
    output reg i_axi4s_dout_tready = 1'b0
)/* synthesis syn_romstyle = "select_rom" */;

reg mem [15:0];

integer i;
initial begin
    for (i=0;i<2**4;i=i+1) begin
        mem[i]= 1'b0;
    end
end

always@(posedge clk or negedge rstn)begin
    if(!rstn)begin
        i_axi4s_dout_tready <= 0;
    end
    else begin
        i_axi4s_dout_tready <= mem[rd_addr];
    end
end
generate
initial begin
mem[0] = 0;
mem[1] =0;
mem[2] =1;
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
mem[13] =0;
mem[14] =0;
mem[15] =0;
end
endgenerate
endmodule