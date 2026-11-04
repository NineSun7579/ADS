module ipsxe_divider_rom_divisor_tdata #(
    parameter DIVISOR_WIDTH = 8
) (
    input clk,
    input rstn,
    input [3:0] rd_addr,
    output reg [DIVISOR_WIDTH-1:0] i_axi4s_divisor_tdata = {DIVISOR_WIDTH{1'b0}}
)/* synthesis syn_romstyle = "select_rom" */;

reg [DIVISOR_WIDTH-1:0] mem [15:0];

integer i;
initial begin
    for (i=0;i<2**4;i=i+1) begin
        mem[i]= {DIVISOR_WIDTH{1'b0}};
    end
end

always@(posedge clk or negedge rstn)begin
    if(!rstn)begin
        i_axi4s_divisor_tdata <= 0;
    end
    else begin
        i_axi4s_divisor_tdata <= mem[rd_addr];
    end
end
generate
initial begin
mem[0] = 0;
mem[1] =16;
mem[2] =0;
mem[3] =45;
mem[4] =5;
mem[5] =10;
mem[6] =10;
mem[7] =10;
mem[8] =10;
mem[9] =6;
mem[10] =6;
mem[11] =6;
mem[12] =6;
mem[13] =37;
mem[14] =37;
mem[15] =37;
end
endgenerate
endmodule