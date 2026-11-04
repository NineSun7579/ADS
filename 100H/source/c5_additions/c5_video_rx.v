`timescale 1ns / 1ps
//===========================================================================
//  sfp_video_rx.v  --  SFP 光口视频接收解包器 (100H 侧)
//
//  链路协议 (与 50K 侧 sfp_video_tx.v 配套, 见其头注释):
//    HSST/HSSTLP CH2, 5Gbps, 8B10B, fabric 32bit @ 125MHz。
//    数据字 (rxk==4'b0000) = 2 个有效像素: rxd = {pix1[15:0], pix0[15:0]}
//      byte0/1 = 先发像素 pix0, byte2/3 = 后发像素 pix1。
//    控制字 (rxk==4'b1001) = {8'hBC, {1'b0,hs,vs,5'b0}, 8'h28, 8'hBC}
//      => vs = rxd[21], hs = rxd[22] (电平随控制字连续更新, de 恒 0)。
//    帧边界 = vs 上升沿, 每帧 1280x480 (双摄合成流, 前640=cam1/后640=cam2)。
//
//  设计要点 -- 符号流 FIFO 保序:
//    数据字拆成 2 个像素符号、控制字作为 vs/hs 事件符号, 共用一个同步 FIFO
//    排队输出。这样即使 RX 侧像素弹出落后于后续控制字到达(链路突发积压),
//    vs/hs 电平更新也不会越过未输出的像素 -- 行/帧标记严格保序。
//
//  输出为标准摄像头式像素流 {vs, hs, de, rgb565}, 与 ov5640 通路同构,
//  下游 splitter 按列拆 cam5/cam6, 本模块不关心行宽。
//
//  时钟域: i_clk = HSST o_p_clk2core_rx_2 (125MHz)。
//===========================================================================
module c5_video_rx #(
    parameter FIFO_AW = 11                   // 符号 FIFO 深度 2^11 = 2048
)(
    input  wire        i_clk,                // 125MHz RX fabric 时钟
    input  wire        i_rst_n,
    input  wire        i_en,                 // 链路同步有效(pcs_lsm_synced & rxlane_done), 0=清状态
    input  wire [31:0] i_rxd,
    input wire i_meta_valid, output reg o_meta_valid,
    output wire o_pending,
    input wire [159:0] i_meta_payload, output reg [159:0] o_meta_payload,
    output reg o_native_meta_ok,
    input  wire [3:0]  i_rxk,
    output reg         o_vs,                 // 锁存电平输出
    output reg         o_hs,
    output reg         o_de,
    output reg  [15:0] o_pix,
    output wire        o_overflow            // 符号 FIFO 溢出指示(调试用)
);

    //-----------------------------------------------------------------------
    // 字型判别与控制字电平抽取
    //-----------------------------------------------------------------------
    wire        w_vs      = i_rxd[21];
    wire        w_hs      = i_rxd[22];
    wire        w_is_data = (i_rxk == 4'b0000);
    wire w_is_ctrl=(i_rxk==4'b1001) && i_rxd[31:24]==8'hbc && i_rxd[15:0]==16'h28bc && (i_rxd[23:16]&8'h9f)==0;

    //-----------------------------------------------------------------------
    // 同步符号 FIFO (simple dual-port, 2048 x 19bit)
    //   符号 = {tag, vs, hs, pix[15:0]}; tag=1 控制符号, tag=0 数据符号。
    //   数据字 -> 压 2 个数据符号; 电平变化的控制字 -> 压 1 个控制符号。
    //
    //   关键: 电平未变的控制/idle 字【不入队直接丢弃】。TX 侧每个 fab 拍
    //   都有字(idle 携带当前电平, 见 sfp_video_tx Rev3.1fix2), 若全部入队,
    //   符号入队率 ~125M/s 超过出队率必然溢出; 只有电平变化才影响输出,
    //   用 shadow 电平判变即可, 保序性不受影响 (变化点仍严格排队)。
    //-----------------------------------------------------------------------
    (* syn_ramstyle="block_ram" *) reg [178:0] mem0 [0:(1<<(FIFO_AW-1))-1];   // even symbol slots
    (* syn_ramstyle="block_ram" *) reg [178:0] mem1 [0:(1<<(FIFO_AW-1))-1];   // odd symbol slots
    reg [FIFO_AW:0] wptr, rptr;
    reg        shadow_vs, shadow_hs;   // 已入队的最新电平

    reg [FIFO_AW:0] committed_wptr;
    wire empty=(committed_wptr==rptr);
    wire [FIFO_AW:0] used = wptr - rptr;

    wire ctrl_chg = w_is_ctrl && ((w_vs != shadow_vs) || (w_hs != shadow_hs));

    wire meta=i_meta_valid && !w_is_data;
    wire pair=w_is_data || (meta && ctrl_chg);
    wire push2=i_en && pair && (used <= ((1<<FIFO_AW)-3));
    wire push1=i_en && !pair && (meta || ctrl_chg) && (used <= ((1<<FIFO_AW)-2));
    wire pushA = push2 | push1;

    wire [FIFO_AW-1:0] wa = wptr[FIFO_AW-1:0];
    wire [FIFO_AW-1:0] wb = wptr[FIFO_AW-1:0] + 1'b1;

    // 写口 A: 数据字时为 pix0, 电平变化控制字时为 vs/hs 事件符号
    wire [178:0] symA={i_meta_payload,(w_is_data?{1'b0,2'b00,i_rxd[15:0]}:
      (meta?{1'b1,shadow_vs,shadow_hs,16'h8000}:{1'b1,w_vs,w_hs,16'b0}))};

    // [BANK 2026-09-30] PDS cannot infer a RAM with two writes per cycle
    // (Sdm-2010). Split by symbol parity so each bank sees one write.
    wire [178:0] symB=w_is_data?{1'b0,2'b00,i_rxd[31:16]}:{1'b1,w_vs,w_hs,16'b0};
    wire        wodd  = wptr[0];
    wire        we0   = push2 | (push1 & ~wodd);
    wire        we1   = push2 | (push1 &  wodd);
    wire [FIFO_AW-2:0] wa0 = wodd ? wb[FIFO_AW-1:1] : wa[FIFO_AW-1:1];
    wire [FIFO_AW-2:0] wa1 = wa[FIFO_AW-1:1];
    wire [178:0] wd0   = wodd ? symB : symA;
    wire [178:0] wd1   = wodd ? symA : symB;
    reg staged_we0,staged_we1;
    reg [FIFO_AW-2:0] staged_addr0,staged_addr1;
    reg [178:0] staged_data0,staged_data1;
    reg [1:0] staged_count;
    // wptr reserves accepted symbols immediately, including this pending stage.
    // Reader sees only committed_wptr, advanced with the actual memory write.
    always @(posedge i_clk or negedge i_rst_n) begin
        if(!i_rst_n) begin
            staged_we0<=0;staged_we1<=0;staged_count<=0;committed_wptr<=0;
            staged_addr0<=0;staged_addr1<=0;staged_data0<=0;staged_data1<=0;
        end else if(!i_en) begin
            staged_we0<=0;staged_we1<=0;staged_count<=0;committed_wptr<=0;
        end else begin
            staged_we0<=we0;staged_we1<=we1;
            staged_addr0<=wa0;staged_addr1<=wa1;
            staged_data0<=wd0;staged_data1<=wd1;
            staged_count<=push2?2'd2:(push1?2'd1:2'd0);
            committed_wptr<=committed_wptr+staged_count;
        end
    end
    // Reset-free BRAM ports. All WE/address/data inputs are aligned registers;
    // raw link enable never drives a primitive write enable combinationally.
    always @(posedge i_clk) begin
        if(staged_we0)mem0[staged_addr0]<=staged_data0;
        if(staged_we1)mem1[staged_addr1]<=staged_data1;
    end

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            wptr <= 0; shadow_vs <= 1'b0; shadow_hs <= 1'b0;
        end
        else if (!i_en) begin
            wptr <= 0; shadow_vs <= 1'b0; shadow_hs <= 1'b0;
        end
        else begin
            wptr <= wptr + (push2 ? 2'd2 : (push1 ? 1'd1 : 1'd0));
            if ((push1 || push2) && ctrl_chg) begin
                shadow_vs <= w_vs;
                shadow_hs <= w_hs;
            end
        end
    end

    //-----------------------------------------------------------------------
    // 读侧: 每拍最多弹 1 个符号, 重建像素流
    //-----------------------------------------------------------------------
    wire        pop  = ~empty & i_en;
    reg [178:0] read_even,read_odd;
    reg fetched,fetched_odd;
    // Two independent synchronous read ports retain symbol parity. Pointer
    // credit returns at fetch; data is already owned by these head registers.
    always @(posedge i_clk) begin
        if(i_rst_n && pop) begin
            read_even<=mem0[rptr[FIFO_AW-1:1]];
            read_odd<=mem1[rptr[FIFO_AW-1:1]];
        end
    end
    always @(posedge i_clk or negedge i_rst_n) begin
        if(!i_rst_n) begin rptr<=0;fetched<=0;fetched_odd<=0;end
        else if(!i_en) begin rptr<=0;fetched<=0;fetched_odd<=0;end
        else begin
            fetched<=pop;
            if(pop) begin rptr<=rptr+1'b1;fetched_odd<=rptr[0];end
        end
    end
    wire [178:0] rsym=fetched_odd?read_odd:read_even;
    // Decode the same FIFO head on the payload capture edge, not one cycle later.
    wire [159:0] head_meta=rsym[178:19];
    wire head_native_ok=head_meta[7:0]==2 && head_meta[15:8]==6 &&
        head_meta[23:16]==5 && head_meta[31:26]==0 && head_meta[127:96]==0 &&
        head_meta[63:32]!=0 && head_meta[159:128]!=0 &&
        ((head_meta[25:24]==2 && head_meta[79:64]==1280 && head_meta[95:80]==480) ||
         (head_meta[25:24]==3 && head_meta[79:64]==1280 && head_meta[95:80]==960));
    assign o_pending=(wptr!=rptr) || fetched || (staged_count!=0);

    always @(posedge i_clk or negedge i_rst_n) begin
        o_meta_valid <= 0;
        if (!i_rst_n) begin
            o_meta_payload<=0;o_native_meta_ok<=0;
            o_vs <= 1'b0; o_hs <= 1'b0; o_de <= 1'b0; o_pix <= 16'b0;
        end
        else if (!i_en) begin
            o_vs <= 1'b0; o_hs <= 1'b0; o_de <= 1'b0;
        end
        else if (fetched) begin
            if (rsym[18]) begin                  // 控制符号: 更新电平, 无像素
                o_de <= 1'b0;
                if(rsym[15]) begin
                    o_meta_valid<=1;o_meta_payload<=rsym[178:19];
                    o_native_meta_ok<=head_native_ok;
                end
                else begin o_vs<=rsym[17];o_hs<=rsym[16];end
            end
            else begin                           // 数据符号: 输出像素
                o_de <= 1'b1;
                o_pix <= rsym[15:0];
            end
        end
        else begin
            o_de <= 1'b0;                        // FIFO 空: 消隐保持电平
        end
    end

    // 溢出脉冲(应恒为 0: 稳态符号率 ~74M/s << 125M/s; 电平不变的 ctrl 不入队属正常)
    reg ovf_q;
    assign o_overflow = ovf_q;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) ovf_q <= 1'b0;
        else ovf_q <= ovf_q || (i_en && ((pair && !push2) || (!pair && (meta || ctrl_chg) && !push1) || (i_meta_valid && w_is_data)));
    end

endmodule
