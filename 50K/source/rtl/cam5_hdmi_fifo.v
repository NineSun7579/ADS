`timescale 1ns/1ps
// HDMI-only donor-compatible banked FIFO. Preserve commit/publication timing:
// posedge registers WE/address/data, negedge writes RAM, next posedge publishes
// the committed Gray pointer. Split WIDTH into <=4-bit physical RAM groups;
// each has a preserved local enable instead of a19-sink bank_write net.
module cam5_hdmi_fifo #(parameter WIDTH=19,DEPTH=2048,GROUP_BITS=4)(
    input wr_clk,wr_rst_n,wr_en,input [WIDTH-1:0] wr_data,output reg full,
    input rd_clk,rd_rst_n,rd_en,output [WIDTH-1:0] rd_data,output reg empty
);
    localparam AW=$clog2(DEPTH),LOW=AW<5 ? AW:5;
    localparam BANK_DEPTH=1<<LOW,BANKS=DEPTH/BANK_DEPTH;
    localparam GROUPS=(WIDTH+GROUP_BITS-1)/GROUP_BITS;
    reg [AW:0]wbin,rbin,wptr,rptr;
    reg [AW:0]wnext,rnext,wgray_next,rgray_next;
    (* ASYNC_REG="TRUE" *)reg [AW:0]wptr_rd1,wptr_rd2,rptr_wr1,rptr_wr2;
    wire [AW-1:0]raddr=rbin[AW-1:0];
    wire [WIDTH-1:0]bank_head[0:BANKS-1];
    // Capture each eight-bank group's next visible head on the pointer edge.
    // Pointer publication already lags committed memory writes. Empty heads are
    // unobservable; valid heads must remain cycle-equivalent to the donor.
    localparam READ_GROUPS=(BANKS+7)/8;
    wire [AW-1:0] head_address=rbin[AW-1:0]+(rd_en && !empty);
    wire [WIDTH-1:0] group_head[0:READ_GROUPS-1];
    genvar rg,rb;
    generate for(rg=0;rg<READ_GROUPS;rg=rg+1)begin:g_read_prefetch
        wire [WIDTH-1:0] words[0:7];
        for(rb=0;rb<8;rb=rb+1)begin:g_word
            if(rg*8+rb<BANKS)begin
                // Separate address is required: at the pointer edge prefetch
                // the successor, rather than capturing the consumed word.
                assign words[rb]=bank_head[rg*8+rb];
            end else begin
                assign words[rb]=0;
            end
        end
        reg [WIDTH-1:0] head /* synthesis syn_preserve=1 */;
        always @(posedge rd_clk) head<=words[(head_address>>LOW)&7];
        assign group_head[rg]=head;
    end endgenerate
    assign rd_data=group_head[(raddr>>LOW)>>3];
    genvar bank,group;
    generate for(bank=0;bank<BANKS;bank=bank+1)begin:g_bank
        wire select_bank=(wbin[AW-1:0]>>LOW)==bank;
        for(group=0;group<GROUPS;group=group+1)begin:g_group
            localparam BASE=group*GROUP_BITS;
            localparam BITS=(WIDTH-BASE)<GROUP_BITS ? WIDTH-BASE:GROUP_BITS;
            reg [BITS-1:0]mem[0:BANK_DEPTH-1];
            // ADS Synthesis User Guide5.15: preservation on the register;
            // 5.11 keep applies to a NET;5.13 maxfan requests replication.
            // Previous combined attributes on a reg did not survive ADS
            // equivalent-register merging; require mapped connectivity proof.
            reg bank_write /* synthesis syn_preserve=1 syn_maxfan=4 */;
            wire local_write /* synthesis syn_keep=1 syn_maxfan=4 */;
            assign local_write=bank_write;
            (* syn_preserve=1 *)reg [LOW-1:0]bank_addr;
            (* syn_preserve=1 *)reg [BITS-1:0]bank_data;
            always @(posedge wr_clk or negedge wr_rst_n)
                if(!wr_rst_n)bank_write<=0;
                else bank_write<=wr_en && !full && select_bank;
            always @(posedge wr_clk)
                if(wr_rst_n && wr_en && !full && select_bank)begin
                    bank_addr<=wbin[LOW-1:0];bank_data<=wr_data[BASE+:BITS];
                end
            always @(negedge wr_clk)if(local_write)mem[bank_addr]<=bank_data;
            assign bank_head[bank][BASE+:BITS]=mem[head_address[LOW-1:0]];
        end
    end endgenerate
    function [AW:0]gray;
        input [AW:0]value;
        gray=(value>>1)^value;
    endfunction
    always @(posedge wr_clk or negedge wr_rst_n)
        if(!wr_rst_n)begin wbin<=0;wptr<=0;full<=0;end
        else begin
            wnext=wbin+(wr_en && !full);
            wbin<=#1 wnext;wgray_next=gray(wnext);
            wptr<=#1 gray(wbin);
            full<=#1 wgray_next=={~rptr_wr2[AW:AW-1],rptr_wr2[AW-2:0]};
        end
    always @(posedge wr_clk or negedge wr_rst_n)
        if(!wr_rst_n)begin rptr_wr1<=0;rptr_wr2<=0;end
        else begin rptr_wr1<=#1 rptr;rptr_wr2<=#1 rptr_wr1;end
    always @(posedge rd_clk or negedge rd_rst_n)
        if(!rd_rst_n)begin rbin<=0;rptr<=0;empty<=1;end
        else begin
            rnext=rbin+(rd_en && !empty);rbin<=#1 rnext;
            rgray_next=gray(rnext);rptr<=#1 rgray_next;
            empty<=#1 rgray_next==wptr_rd2;
        end
    always @(posedge rd_clk or negedge rd_rst_n)
        if(!rd_rst_n)begin wptr_rd1<=0;wptr_rd2<=0;end
        else begin wptr_rd1<=#1 wptr;wptr_rd2<=#1 wptr_rd1;end
endmodule
