//============================================================================
// prep_sync_fifo.v : 同步 FIFO (推断 BRAM, 无 IP 依赖, 仿真/综合一致)
// 近满 prog_full 用于上游 s_ready 反压, 保证无溢出
//============================================================================
module prep_sync_fifo #(
    parameter DW        = 16,
    parameter DEPTH     = 512,                 // 2 的幂
    parameter AW        = $clog2(DEPTH),
    parameter AFULL     = DEPTH - 32           // 近满阈值
)(
    input  wire        clk,
    input  wire        rst_n,                  // 同步释放由顶层保证
    input  wire        wr_en,
    input  wire [DW-1:0] wr_data,
    input  wire        rd_en,
    output wire [DW-1:0] rd_data,
    output wire        rd_valid,               // 非空
    output wire        prog_full,              // 近满: 计数 >= AFULL
    output wire [AW:0] cnt
);

    reg [DW-1:0] mem [0:DEPTH-1];
    reg [AW:0]   wptr, rptr;

    assign cnt       = wptr - rptr;
    assign prog_full = (cnt >= AFULL[AW:0]);
    assign rd_valid  = (cnt != 0);
    assign rd_data   = mem[rptr[AW-1:0]];

    always @(posedge clk) begin
        if (wr_en) mem[wptr[AW-1:0]] <= wr_data;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)      wptr <= 0;
        else if (wr_en)  wptr <= wptr + 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)                    rptr <= 0;
        else if (rd_en && rd_valid)    rptr <= rptr + 1'b1;
    end

endmodule
