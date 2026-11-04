module ipsxe_divider_rom_dividend_tvalid 
(
    input clk,
    input rstn,
    input [3:0] rd_addr,
    output reg i_axi4s_dividend_tvalid = 1'b0
)/* synthesis syn_romstyle = "select_rom" */;

reg mem [15:0];
reg [4:0] counter = 4'b0; 

integer i;
initial begin
    for (i=0;i<2**4;i=i+1) begin
        mem[i]= 1'b0;
    end
end

always@(posedge clk or negedge rstn) begin
    if(!rstn) begin
        i_axi4s_dividend_tvalid <= 0;
        counter <= 0;
    end
    else begin
        if(counter != 0) begin
            counter <= counter - 1;
            i_axi4s_dividend_tvalid <= 0;
        end
        else if(mem[rd_addr]) begin
            i_axi4s_dividend_tvalid <= 1;
            counter <= 20; 
        end
        else begin
            i_axi4s_dividend_tvalid <= 0;
        end
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