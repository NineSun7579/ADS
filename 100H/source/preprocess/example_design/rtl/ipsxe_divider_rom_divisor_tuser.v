module ipsxe_divider_rom_divisor_tuser #(
    parameter DIVISOR_TUSER_WIDTH = 8
) (
    input clk,
    input rstn,
    input [3:0] rd_addr,
    output reg [DIVISOR_TUSER_WIDTH-1:0] i_axi4s_divisor_tuser = {DIVISOR_TUSER_WIDTH{1'b0}}
)/* synthesis syn_romstyle = "select_rom" */;

reg [DIVISOR_TUSER_WIDTH-1:0] mem [15:0];

integer i;
initial begin
    for (i=0;i<2**4;i=i+1) begin
        mem[i]= {DIVISOR_TUSER_WIDTH{1'b0}};
    end
end

always@(posedge clk or negedge rstn)begin
    if(!rstn)begin
        i_axi4s_divisor_tuser <= 0;
    end
    else begin
        i_axi4s_divisor_tuser <= mem[rd_addr];
    end
end
generate
initial begin
mem[0] = 0;
mem[1] =10;
mem[2] =0;
mem[3] =35;
mem[4] =145;
mem[5] =36;
mem[6] =36;
mem[7] =36;
mem[8] =36;
mem[9] =45;
mem[10] =45;
mem[11] =45;
mem[12] =45;
mem[13] =68;
mem[14] =68;
mem[15] =68;
end
endgenerate
endmodule