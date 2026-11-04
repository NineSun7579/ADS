`timescale 1ns/1ps
// External client for the 50K vendor DDR port. No protected IP dependencies.
module c6_coherent_framebuffer #(
    parameter W=640, H=480,
    parameter ROW_BEATS=((W+255)/256)*16,
    parameter [27:0] PAGE0=28'h0100000, PAGE1=28'h0140000, PAGE2=28'h0180000,
    parameter WATCHDOG=16777215
)(
    input s_clk, s_rst_n, input s_sof, s_eof, s_de, s_eol,
    input [15:0] s_pixel, input [31:0] s_sequence, input [15:0] s_epoch,
    input d_clk, d_rst_n, input [15:0] config_epoch,
    input m_clk, m_rst_n,
    input frame_request, output frame_ready, input frame_release,
    output reg [31:0] frame_sequence, output reg [15:0] frame_epoch,
    input [9:0] row_index, pixel_address, input row_consume,
    output row_ready, output [15:0] pixel_data,
    output reg [27:0] awaddr, output [3:0] awid, awlen,
    output reg awvalid, input awready,
    output reg [255:0] wdata, output [31:0] wstrb,
    input wready, wlast,
    output reg [27:0] araddr, output [3:0] arid, arlen,
    output reg arvalid, input arready,
    input [255:0] rdata, input rvalid, rlast, input [3:0] rid,
    output fault, output reg [31:0] published_count, rejected_count
);
    localparam AB=W/16, RB=ROW_BEATS, CMDS=RB/16;
    // Production ties all three ports to the same raw common reset request.
    // Any port can still assert reset globally, including with stopped clocks.
    // Only stage zero sees that request; each final stage releases locally.
    wire reset_n=s_rst_n & d_rst_n & m_rst_n;
    (* ASYNC_REG = "TRUE" *) reg [1:0] sr,dr,mr;
    always @(posedge s_clk or negedge reset_n)
        if(!reset_n) sr[0]<=0; else sr[0]<=1'b1;
    always @(posedge s_clk or negedge sr[0])
        if(!sr[0]) sr[1]<=0; else sr[1]<=1'b1;
    always @(posedge d_clk or negedge reset_n)
        if(!reset_n) dr[0]<=0; else dr[0]<=1'b1;
    always @(posedge d_clk or negedge dr[0])
        if(!dr[0]) dr[1]<=0; else dr[1]<=1'b1;
    always @(posedge m_clk or negedge reset_n)
        if(!reset_n) mr[0]<=0; else mr[0]<=1'b1;
    always @(posedge m_clk or negedge mr[0])
        if(!mr[0]) mr[1]<=0; else mr[1]<=1'b1;
    wire s_reset_n=sr[1],d_reset_n=dr[1],m_reset_n=mr[1];
    reg sfault, dfault;
    (* ASYNC_REG = "TRUE" *) reg dfault_s1,dfault_s2;
    (* ASYNC_REG = "TRUE" *) reg sfault_d1,sfault_d2;
    always @(posedge s_clk or negedge s_reset_n) begin
        if(!s_reset_n) begin dfault_s1<=0;dfault_s2<=0;end
        else begin dfault_s1<=dfault;dfault_s2<=dfault_s1;end
    end
    always @(posedge d_clk or negedge d_reset_n) begin
        if(!d_reset_n) begin sfault_d1<=0;sfault_d2<=0;end
        else begin sfault_d1<=sfault;sfault_d2<=sfault_d1;end
    end
    wire s_fault=sfault|dfault_s2;
    wire d_fault=dfault|sfault_d2;
    // Asynchronous status only; domain decisions use synchronized remote faults.
    assign fault=sfault|dfault;
    assign awid=4'h6; assign arid=4'h6;
    assign awlen=15; assign arlen=15; assign wstrb=32'hffffffff;
    function [27:0] base;
        input [1:0] p;
        begin case(p) 0:base=PAGE0; 1:base=PAGE1; default:base=PAGE2; endcase end
    endfunction

    // Two acknowledged row mailboxes. Metadata and RAM remain stable until ack.
    reg [255:0] capture_ram [0:2*AB-1];
    reg [1:0] row_send, row_ack;
    reg [9:0] capture_y [0:1];
    reg [1:0] ack_s1,ack_s2;
    reg grant, grant_s1,grant_s2,grant_seen;
    reg start_send, end_send;
    reg [31:0] capture_sequence;
    reg [15:0] capture_epoch;
    reg end_good;
    reg active, bad, row_open;
    integer sx,sy;
    reg [255:0] pack;
    reg chosen_slot;
    reg [31:0] cap_pixels;
    always @(posedge s_clk or negedge s_reset_n) begin
        if(!s_reset_n) begin
            row_send<=0; ack_s1<=0; ack_s2<=0;
            grant_s1<=0;grant_s2<=0;grant_seen<=0;
            start_send<=0;end_send<=0;active<=0;bad<=0;sfault<=0;
            sx<=0;sy<=0;pack<=0;chosen_slot<=0;row_open<=0;
            capture_sequence<=0;capture_epoch<=0;end_good<=0;cap_pixels<=0;
            capture_y[0]<=0;capture_y[1]<=0;
        end else begin
            ack_s1<=row_ack;ack_s2<=ack_s1;grant_s1<=grant;grant_s2<=grant_s1;
            if(s_sof) begin
                if(active) begin sfault<=1;active<=0; end
                else if(grant_s2!=grant_seen && !s_fault) begin
                    grant_seen<=grant_s2;start_send<=~start_send;
                    capture_sequence<=s_sequence;capture_epoch<=s_epoch;
                    active<=1;bad<=s_de|s_eol|s_eof;sx<=0;sy<=0;cap_pixels<=0;
                    pack<=0;row_open<=0;
                end
            end else if(active) begin
                if(s_de) begin
                    cap_pixels<=cap_pixels+1;
                    row_open<=1;
                    if(sx==0) begin
                        chosen_slot<=sy[0];
                        if(row_send[sy[0]]!=ack_s2[sy[0]]) begin bad<=1;sfault<=1; end
                    end
                    if(sx>=W || sy>=H) bad<=1;
                    else begin
                        // sx is reset to zero and accepted only in [0,W).
                        // Explicit low bits avoid ADS's unmapped signed MOD.
                        pack[sx[3:0]*16 +:16]<=s_pixel;
                        if(sx[3:0]==15 && !bad && (sx!=0 || row_send[sy[0]]==ack_s2[sy[0]]))
                            capture_ram[sy[0]*AB+sx[31:4]]<={s_pixel,pack[239:0]};
                    end
                    sx<=sx+1;
                end
                if(s_eol) begin
                    if(sx+(s_de?1:0)!=W || sy>=H || (!row_open && !s_de)) bad<=1;
                    else if(!bad) begin
                        capture_y[sy[0]]<=sy;
                        row_send[sy[0]]<=~row_send[sy[0]];
                    end
                    sx<=0;sy<=sy+1;row_open<=0;
                end
                if(s_eof) begin
                    end_good<=!bad && !s_de && !s_eol && sx==0 && sy==H && cap_pixels==W*H;
                    end_send<=~end_send;active<=0;
                end
            end
        end
    end

    // Merge-domain consumer mailbox and synchronous RAM output.
    reg [255:0] display_ram [0:2*AB-1];
    reg [1:0] slot_send,slot_m1,slot_m2,slot_seen,slot_valid;
    reg [9:0] slot_y [0:1];
    reg [9:0] my [0:1];
    reg [1:0] consume_send;
    reg request_send,release_send,release_ack;
    reg rel_m1,rel_m2;
    reg descriptor_send,desc_m1,desc_m2,desc_seen;
    reg [31:0] descriptor_seq;
    reg [15:0] descriptor_epoch;
    reg waiting,pinned_m;
    reg fault_m1,fault_m2;
    reg [15:0] epoch_m1,epoch_m2;
    reg [255:0] pixel_word;
    reg [3:0] pixel_lane;
    wire selected_slot=row_index[0];
    assign frame_ready=pinned_m && !fault_m2 && frame_epoch==epoch_m2;
    assign row_ready=frame_ready && slot_valid[selected_slot] && my[selected_slot]==row_index && row_index<H;
    assign pixel_data=pixel_word >> (pixel_lane*16);
    always @(posedge m_clk) begin
        pixel_word<=display_ram[selected_slot*AB+pixel_address/16];
        pixel_lane<=pixel_address[3:0];
    end
    integer mi;
    always @(posedge m_clk or negedge m_reset_n) begin
        if(!m_reset_n) begin
            slot_m1<=0;slot_m2<=0;slot_seen<=0;slot_valid<=0;
            consume_send<=0;request_send<=0;release_send<=0;rel_m1<=0;rel_m2<=0;
            desc_m1<=0;desc_m2<=0;desc_seen<=0;waiting<=0;pinned_m<=0;
            frame_sequence<=0;frame_epoch<=0;fault_m1<=0;fault_m2<=0;
            epoch_m1<=0;epoch_m2<=0;my[0]<=0;my[1]<=0;
        end else begin
            slot_m1<=slot_send;slot_m2<=slot_m1;
            desc_m1<=descriptor_send;desc_m2<=desc_m1;
            rel_m1<=release_ack;rel_m2<=rel_m1;
            fault_m1<=fault;fault_m2<=fault_m1;epoch_m1<=config_epoch;epoch_m2<=epoch_m1;
            for(mi=0;mi<2;mi=mi+1) if(slot_m2[mi]!=slot_seen[mi]) begin
                slot_seen[mi]<=slot_m2[mi];my[mi]<=slot_y[mi];
                if(waiting || pinned_m) slot_valid[mi]<=1;
            end
            if(frame_request && !waiting && !pinned_m && rel_m2==release_send && !fault_m2) begin
                request_send<=~request_send;waiting<=1;slot_valid<=0;
            end
            if(desc_m2!=desc_seen) begin
                desc_seen<=desc_m2;
                if(waiting && descriptor_epoch==epoch_m2 && !fault_m2) begin
                    frame_sequence<=descriptor_seq;frame_epoch<=descriptor_epoch;
                    pinned_m<=1;waiting<=0;
                end
            end
            if(row_consume && row_ready) begin
                slot_valid[selected_slot]<=0;consume_send[selected_slot]<=~consume_send[selected_slot];
            end
            if(frame_release && pinned_m) begin
                release_send<=~release_send;pinned_m<=0;waiting<=0;slot_valid<=0;
            end
            if(fault_m2 || (pinned_m && frame_epoch!=epoch_m2)) begin
                pinned_m<=0;slot_valid<=0;
            end
        end
    end

    // DDR owns page state exclusively. 0 free, 1 capture, 2 ready, 3 pinned.
    reg [1:0] page_state [0:2];
    reg [31:0] page_seq [0:2];
    reg [15:0] page_epoch [0:2];
    reg [1:0] capture_page,pin_page;
    reg granted,started,ended,good_end;
    reg [31:0] native_seq;
    reg [15:0] native_epoch;
    reg [31:0] last_sequence;
    reg have_last;
    reg [15:0] epoch_seen;
    reg [1:0] row_d1,row_d2;
    reg start_d1,start_d2,start_seen,end_d1,end_d2,end_seen;
    reg req_d1,req_d2,req_seen,rel_d1,rel_d2,rel_seen,request_pending;
    reg [1:0] consume_d1,consume_d2,consume_seen;
    reg pinned_d,descriptor_pending;
    reg [1:0] fill_pending,filled;
    reg [9:0] fill_y [0:1];
    // Admission below forbids row H; only a completed admitted row increments.
    // Thus written_rows is unsigned in [0,H], including the publication value H.
    localparam WRITTEN_ROWS_WIDTH=$clog2(H+1);
    reg [WRITTEN_ROWS_WIDTH-1:0] written_rows;
    wire [31:0] written_rows_address=written_rows;
    // Watchdog timers count 0..WATCHDOG=16777215 then fault. The increment and
    // the >=WATCHDOG compare are the only reads, and dfault latches in the same
    // branch, so no increment past 16777215 is ever observed in operation:
    // WATCHDOG+1=2^24 needs $clog2(2^24)=24 bits, domain [0,16777215].
    reg [$clog2(WATCHDOG+1)-1:0] cap_timer,io_timer;
    integer free_choice,ready_choice,di,k;
    reg [3:0] state;
    localparam IDLE=0, WADDR=1, WDATA=2, RADDR=3, RDATA=4;
    reg transfer_slot;
    // beat_no counts the 16 AXI beats of one fixed burst (AWLEN/ARLEN=15).
    // It is reset to 0 at each command/transfer start and incremented only in
    // the beat_no!=15 branch; at beat_no==15 the code resets to 0 (new command)
    // or terminates, so the domain is exactly 0..15 and 4 bits are sufficient.
    reg [3:0] beat_no;
    // command_no counts the CMDS=RB/16 commands of one transfer. Reset to 0 at
    // transfer start; incremented only in the beat_no==15 && command_no!=CMDS-1
    // branch, so a post-increment value never exceeds CMDS-1 (the ==CMDS-1
    // branch terminates, it never increments). Domain is 0..CMDS-1. For
    // W=640: CMDS=3 -> $clog2(3)=2 bits. CMDS=1 (small geometry) must still
    // declare one bit; the counter is then constant 0.
    localparam CMD_NO_W=(CMDS>1)?$clog2(CMDS):1;
    reg [CMD_NO_W-1:0] command_no;
    reg [9:0] transfer_y;
    reg [1:0] transfer_page;
    // transfer_y is drawn only from capture_y/fill_y, both gated to [0,H-1]
    // (capture_y is written only when sy<H; fill_y only when slot_y+2<H), so
    // row_offset=transfer_y*RB*8 <= (H-1)*RB*8 < 2^$clog2(H*RB*8). For
    // W=640,H=480,RB=48: 479*48*8=183936 < 2^18=262144. Only use is inside the
    // 28-bit base()+row_offset+... awaddr/araddr sums, zero-extended identically.
    wire [$clog2(H*RB*8)-1:0] row_offset=transfer_y*RB*8;
    always @* begin
        free_choice=-1;ready_choice=-1;
        for(k=0;k<3;k=k+1) begin
            if(page_state[k]==0) free_choice=k;
            if(page_state[k]==2 && page_epoch[k]==config_epoch && (!have_last || page_seq[k]>last_sequence)) begin
                if(ready_choice<0) ready_choice=k;
                else if(page_seq[k]>page_seq[ready_choice]) ready_choice=k;
            end
        end
    end
    always @(posedge d_clk or negedge d_reset_n) begin
        if(!d_reset_n) begin
            row_d1<=0;row_d2<=0;row_ack<=0;
            start_d1<=0;start_d2<=0;start_seen<=0;end_d1<=0;end_d2<=0;end_seen<=0;
            req_d1<=0;req_d2<=0;req_seen<=0;rel_d1<=0;rel_d2<=0;rel_seen<=0;
            consume_d1<=0;consume_d2<=0;consume_seen<=0;release_ack<=0;
            request_pending<=0;grant<=0;granted<=0;started<=0;ended<=0;good_end<=0;
            capture_page<=0;pin_page<=0;native_seq<=0;native_epoch<=0;
            last_sequence<=0;have_last<=0;epoch_seen<=0;
            pinned_d<=0;descriptor_pending<=0;descriptor_send<=0;
            descriptor_seq<=0;descriptor_epoch<=0;slot_send<=0;filled<=0;fill_pending<=0;
            slot_y[0]<=0;slot_y[1]<=0;fill_y[0]<=0;fill_y[1]<=1;
            written_rows<=0;cap_timer<=0;io_timer<=0;state<=IDLE;
            transfer_slot<=0;transfer_y<=0;transfer_page<=0;command_no<=0;beat_no<=0;
            awaddr<=0;awvalid<=0;araddr<=0;arvalid<=0;wdata<=0;
            dfault<=0;published_count<=0;rejected_count<=0;
            for(di=0;di<3;di=di+1) begin page_state[di]<=0;page_seq[di]<=0;page_epoch[di]<=0;end
        end else begin
            row_d1<=row_send;row_d2<=row_d1;
            start_d1<=start_send;start_d2<=start_d1;end_d1<=end_send;end_d2<=end_d1;
            req_d1<=request_send;req_d2<=req_d1;rel_d1<=release_send;rel_d2<=rel_d1;
            consume_d1<=consume_send;consume_d2<=consume_d1;
            if(req_d2!=req_seen) begin req_seen<=req_d2;request_pending<=1;end
            if(config_epoch!=epoch_seen) begin
                epoch_seen<=config_epoch;have_last<=0;
                for(di=0;di<3;di=di+1) if(page_state[di]==2) page_state[di]<=0;
                // Configuration changes while a frame is pinned require a coordinated reset.
                if(pinned_d) dfault<=1;
            end
            if(start_d2!=start_seen) begin
                start_seen<=start_d2;started<=1;written_rows<=0;cap_timer<=0;
                native_seq<=capture_sequence;native_epoch<=capture_epoch;
                if(!granted || started) dfault<=1;
            end
            if(end_d2!=end_seen) begin
                end_seen<=end_d2;ended<=1;good_end<=end_good;cap_timer<=0;
            end
            if(started) begin
                cap_timer<=cap_timer+1;
                if(cap_timer>=WATCHDOG) dfault<=1;
            end
            if(state!=IDLE) begin
                io_timer<=io_timer+1;
                if(io_timer>=WATCHDOG) dfault<=1;
            end else io_timer<=0;
            if(d_fault) begin awvalid<=0;arvalid<=0; end
            else begin
                // Allocate only free pages; ready descriptors can be superseded, never pinned pages.
                if(!granted && state==IDLE && config_epoch==epoch_seen) begin
                    if(free_choice>=0) begin
                        capture_page<=free_choice;page_state[free_choice]<=1;
                        granted<=1;grant<=~grant;started<=0;ended<=0;written_rows<=0;
                    end else if(!request_pending) begin
                        for(di=0;di<3;di=di+1) if(page_state[di]==2) page_state[di]<=0;
                    end
                end
                if(ended && state==IDLE && row_d2==row_ack) begin
                    if(good_end && written_rows==H && native_epoch==config_epoch &&
                       (!have_last || native_seq>last_sequence)) begin
                        for(di=0;di<3;di=di+1) if(page_state[di]==2) page_state[di]<=0;
                        page_state[capture_page]<=2;page_seq[capture_page]<=native_seq;
                        page_epoch[capture_page]<=native_epoch;published_count<=published_count+1;
                    end else begin page_state[capture_page]<=0;rejected_count<=rejected_count+1;end
                    granted<=0;started<=0;ended<=0;
                end
                if(request_pending && !pinned_d && ready_choice>=0 && state==IDLE && !ended) begin
                    pin_page<=ready_choice;page_state[ready_choice]<=3;pinned_d<=1;
                    last_sequence<=page_seq[ready_choice];have_last<=1;
                    descriptor_seq<=page_seq[ready_choice];descriptor_epoch<=page_epoch[ready_choice];
                    fill_pending<=3;filled<=0;fill_y[0]<=0;fill_y[1]<=1;
                    descriptor_pending<=1;request_pending<=0;
                end
                if(descriptor_pending && filled==3) begin
                    descriptor_send<=~descriptor_send;descriptor_pending<=0;
                end
                for(di=0;di<2;di=di+1) if(consume_d2[di]!=consume_seen[di]) begin
                    consume_seen[di]<=consume_d2[di];filled[di]<=0;
                    if(pinned_d && slot_y[di]+2<H) begin
                        fill_y[di]<=slot_y[di]+2;fill_pending[di]<=1;
                    end
                end
                if(rel_d2!=rel_seen && state==IDLE) begin
                    rel_seen<=rel_d2;release_ack<=rel_d2;
                    if(pinned_d) page_state[pin_page]<=0;
                    pinned_d<=0;fill_pending<=0;filled<=0;descriptor_pending<=0;
                end
                case(state)
                    IDLE: begin
                        // Prefetch gets priority over row writes; capture FIFO overflow is fatal.
                        if(pinned_d && |fill_pending && rel_d2==rel_seen) begin
                            transfer_slot<=!fill_pending[0];
                            transfer_y<=fill_pending[0]?fill_y[0]:fill_y[1];
                            transfer_page<=pin_page;command_no<=0;beat_no<=0;
                            araddr<=base(pin_page)+(fill_pending[0]?fill_y[0]:fill_y[1])*RB*8;
                            arvalid<=1;state<=RADDR;
                        end else if(started && |(row_d2^row_ack)) begin
                            // Strict order also detects a missing/duplicated row mailbox.
                            transfer_slot<=written_rows[0];
                            if(row_d2[written_rows[0]]==row_ack[written_rows[0]] ||
                               capture_y[written_rows[0]]!=written_rows || written_rows>=H) dfault<=1;
                            else begin
                                transfer_y<=capture_y[written_rows[0]];transfer_page<=capture_page;
                                command_no<=0;beat_no<=0;
                                 awaddr<=base(capture_page)+written_rows_address*RB*8;awvalid<=1;
                                wdata<=capture_ram[written_rows[0]*AB];state<=WADDR;
                            end
                        end
                    end
                    WADDR: if(awvalid && awready) begin awvalid<=0;state<=WDATA;io_timer<=0;end
                    WDATA: if(wready) begin
                        io_timer<=0;
                        if(wlast!=(beat_no==15)) dfault<=1;
                        if(beat_no==15) begin
                            if(command_no==CMDS-1) begin
                                row_ack[transfer_slot]<=row_d2[transfer_slot];
                                 if(written_rows>=H) dfault<=1;
                                 else written_rows<=written_rows+1'b1;
                                 state<=IDLE;cap_timer<=0;
                            end else begin
                                command_no<=command_no+1;beat_no<=0;
                                awaddr<=base(transfer_page)+row_offset+(command_no+1)*128;
                                awvalid<=1;state<=WADDR;
                                if((command_no+1)*16<AB) wdata<=capture_ram[transfer_slot*AB+(command_no+1)*16];
                                else wdata<=0;
                            end
                        end else begin
                            beat_no<=beat_no+1;
                            if(command_no*16+beat_no+1<AB)
                                wdata<=capture_ram[transfer_slot*AB+command_no*16+beat_no+1];
                            else wdata<=0;
                        end
                    end
                    RADDR: if(arvalid && arready) begin arvalid<=0;state<=RDATA;io_timer<=0;end
                    RDATA: if(rvalid) begin
                        io_timer<=0;
                        if(rid!=6 || rlast!=(beat_no==15)) dfault<=1;
                        if(command_no*16+beat_no<AB)
                            display_ram[transfer_slot*AB+command_no*16+beat_no]<=rdata;
                        if(beat_no==15) begin
                            if(command_no==CMDS-1) begin
                                slot_y[transfer_slot]<=transfer_y;slot_send[transfer_slot]<=~slot_send[transfer_slot];
                                filled[transfer_slot]<=1;fill_pending[transfer_slot]<=0;state<=IDLE;
                            end else begin
                                command_no<=command_no+1;beat_no<=0;
                                araddr<=base(transfer_page)+row_offset+(command_no+1)*128;
                                arvalid<=1;state<=RADDR;
                            end
                        end else beat_no<=beat_no+1;
                    end
                    default: state<=IDLE;
                endcase
                if((wready && state!=WDATA) || (rvalid && state!=RDATA)) dfault<=1;
            end
        end
    end
endmodule
