`timescale 1ns/1ps
// Donor packetizer architecture and skip/guard schedule. Pending pixels survive
// interior DE gaps; only explicit EOL/SOF may close an even-width native row.
module cam5_video_tx #(parameter TX_GE_SKIP_ENABLE=1)(
    input vid_clk,vid_rst_n,input [18:0] vid_data,
    input fab_clk,fab_rst_n,link_ready,
    output reg [31:0] txd,output reg [3:0] txk,output fault
);
    wire empty,full;wire [18:0] rdata;wire pop=!empty;
    video_async_fifo #(.WIDTH(19),.DEPTH(512)) fifo(
        .wr_clk(vid_clk),.wr_rst_n(vid_rst_n),.wr_en(1'b1),.wr_data(vid_data),.full(full),
        .rd_clk(fab_clk),.rd_rst_n(fab_rst_n),.rd_en(pop),.rd_data(rdata),.empty(empty));
    reg input_fault;
    always @(posedge vid_clk or negedge vid_rst_n)
        if(!vid_rst_n)input_fault<=0;else if(full)input_fault<=1;
    (* ASYNC_REG="TRUE" *)reg [1:0] ready_sync,fault_sync;
    reg [18:0] head;
    reg head_valid,head_go;
    wire payload_go=ready_sync[1] && head_go;
    always @(posedge fab_clk or negedge fab_rst_n)
        if(!fab_rst_n)begin
            ready_sync<=0;fault_sync<=0;head<=0;head_valid<=0;head_go<=0;
        end else begin
            ready_sync<={ready_sync[0],link_ready};fault_sync<={fault_sync[0],input_fault};
            head_valid<=pop;head_go<=ready_sync[1];if(pop)head<=rdata;
        end
    wire [31:0] ctrl={8'hbc,1'b0,head[17],head[18],5'd0,8'h28,8'hbc};
    reg last_vs,last_hs;
    wire [31:0] idle={8'hbc,1'b0,last_hs,last_vs,5'd0,8'h28,8'hbc};
    always @(posedge fab_clk or negedge fab_rst_n)
        if(!fab_rst_n)begin last_vs<=0;last_hs<=0;end
        else if(head_valid)begin last_vs<=head[18];last_hs<=head[17];end
    reg pending,wait_frame,output_fault;
    reg [15:0] pix0;
    reg [31:0] producer;
    reg [3:0] producer_k;
    assign fault=output_fault || fault_sync[1];
    always @(posedge fab_clk or negedge fab_rst_n)
        if(!fab_rst_n)begin
            pending<=0;pix0<=0;wait_frame<=1;output_fault<=0;
            producer<=32'hbc0028bc;producer_k<=9;
        end else if(!payload_go || fault)begin
            producer<=head_valid ? ctrl : idle;producer_k<=9;
            pending<=0;wait_frame<=1;
        end else if(head_valid)begin
            producer<=ctrl;producer_k<=9;
            if(wait_frame)begin
                pending<=0;if(head[18] && !head[16])wait_frame<=0;
            end else if(head[16])begin
                if(pending)begin
                    producer<={head[15:0],pix0};producer_k<=0;pending<=0;
                end else begin pix0<=head[15:0];pending<=1;end
            end else if(head[17] || head[18])begin
                if(pending)output_fault<=1;
                pending<=0;
            end
            // Otherwise an interior gap preserves pending, including pix0.
        end else begin producer<=idle;producer_k<=9;end
    reg [31:0] d0,d1,d2,last_ctrl;
    reg [3:0] k0,k1,k2;
    reg [4:0] idle_phase;
    wire redundant=k2==9 && d2==last_ctrl;
    wire following=k1==9 && k0==9 && producer_k==9 &&
        d1==d2 && d0==d2 && producer==d2;
    always @(posedge fab_clk or negedge fab_rst_n)
        if(!fab_rst_n)begin
            d0<=32'hbc0028bc;d1<=32'hbc0028bc;d2<=32'hbc0028bc;
            k0<=9;k1<=9;k2<=9;last_ctrl<=32'hbc0028bc;idle_phase<=0;
            txd<=32'hbc0028bc;txk<=9;
        end else if(!payload_go)begin
            d0<=head_valid ? ctrl : idle;d1<=head_valid ? ctrl : idle;d2<=head_valid ? ctrl : idle;
            k0<=9;k1<=9;k2<=9;txd<=head_valid ? ctrl : idle;txk<=9;
            last_ctrl<=head_valid ? ctrl : idle;idle_phase<=0;
        end else begin
            d0<=producer;d1<=d0;d2<=d1;k0<=producer_k;k1<=k0;k2<=k1;
            idle_phase<=idle_phase+1'b1;txd<=d2;txk<=k2;
            if(redundant && k1==0)begin txd<=32'hffbcffbc;txk<=5;end
            else if(TX_GE_SKIP_ENABLE && redundant && following && idle_phase==0 && d2[22:21]==0)
                begin txd<=32'h50bc50bc;txk<=5;end
            if(k2==9)last_ctrl<=d2;
        end
endmodule
