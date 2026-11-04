// Small ordered output queue for native raster symbols, registered output.
// The BRAM FIFO is FWFT: with rd_ready held, every cycle with !empty presents
// one newly fetched word, consumed in that same cycle.
module c5_native_output_fifo #(parameter WIDTH=37,DEPTH=1024)(
    input wire wr_clk,input wire wr_rst_n,input wire wr_valid,input wire [WIDTH-1:0] wr_data,
    output wire full,
    input wire rd_clk,input wire rd_rst_n,input wire rd_ready,
    output reg rd_valid,output reg [WIDTH-1:0] rd_data,output wire empty
);
    wire [WIDTH-1:0] rd_data_i;
    c5_bram_async_fifo #(.WIDTH(WIDTH),.DEPTH(DEPTH)) fifo(
        .wr_clk(wr_clk),.wr_rst_n(wr_rst_n),.wr_en(wr_valid),.wr_data(wr_data),.full(full),
        .rd_clk(rd_clk),.rd_rst_n(rd_rst_n),.rd_en(rd_ready),.rd_data(rd_data_i),.empty(empty));
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if(!rd_rst_n)begin rd_valid<=0;rd_data<=0;end
        else begin
            rd_valid<=rd_ready && !empty;
            if(rd_ready && !empty)rd_data<=rd_data_i;
        end
    end
endmodule
