`timescale 1ns/1ps
// Generalized line-page architecture from cam2_merge. HD defaults produce
// exactly 2560x720; B is native 640x480. No snapshot/repeated B rows. Native
// page addresses are 11 bits (including columns 1024..1279). corr_mode=0's
// original BGR565->RGB565 swap is retained on both camera inputs.
module cam5_asymmetric_merge #(
    parameter A_WIDTH=1280, A_HEIGHT=720, B_WIDTH=640, B_HEIGHT=480,
    parameter SLOT_WIDTH=1280, OUT_HEIGHT=720,
    parameter ROW_TIMEOUT=16000000, // 64ms @62.5MHz, including first sensor SOF.
    // Per-row budget for waiting on C6 while in lockstep. Must stay well under
    // C5's 45us line time (2812 cycles at 62.5 MHz), otherwise C5's two-slot
    // page ring is overwritten while this row is still waiting.
    parameter BWAIT=1200
)(
    input a_clk, a_rst_n, input [15:0] a_data, input a_de, a_vs,
    input b_clk, b_rst_n, input [15:0] b_data, input b_de, b_vs,
    input o_clk, o_rst_n,
    output reg [15:0] c_data, output reg c_de, c_vs,
    output fault, output reg frame_complete, output reg b_missing,
    output [3:0] fault_src
);
    wire av, bv, af, bf, aseen, bseen;

    wire [15:0] ad, bd;
    wire [9:0] ar, br;
    wire [7:0] ae, be, alatest, blatest;
    reg ac, bc;
    reg [10:0] addr_a, addr_b;
    cam5_line_pages #(.WIDTH(A_WIDTH),.HEIGHT(A_HEIGHT)) a_pages(
        .pclk(a_clk),.p_rst_n(a_rst_n),
        .pixel({a_data[4:0],a_data[10:5],a_data[15:11]}),.de(a_de),.vs(a_vs),
        .oclk(o_clk),.o_rst_n(o_rst_n),.consume(ac),.address(addr_a),
        .valid(av),.data(ad),.row(ar),.frame(ae),.latest_frame(alatest),
        .seen_frame(aseen),.fault(af));
    cam5_line_pages #(.WIDTH(B_WIDTH),.HEIGHT(B_HEIGHT)) b_pages(
        .pclk(b_clk),.p_rst_n(b_rst_n),
        .pixel({b_data[4:0],b_data[10:5],b_data[15:11]}),.de(b_de),.vs(b_vs),
        .oclk(o_clk),.o_rst_n(o_rst_n),.consume(bc),.address(addr_b),
        .valid(bv),.data(bd),.row(br),.frame(be),.latest_frame(blatest),
        .seen_frame(bseen),.fault(bf));
    localparam WAIT_ROW=0, PIXELS=1, GAP=2, VSYNC=3, FAILED=4;
    reg [2:0] state;
    reg [11:0] x;
    reg [9:0] y;
    reg [7:0] frame_a, frame_b;
    reg use_b, local_fault;
    reg b_any;      // C6 delivered at least one page during this output frame
    reg b_started;  // C6 has published a page since this frame began
    reg [31:0] wait_count;
    reg [12:0] blank_count;
    assign fault=af || bf || local_fault;
    // Diagnostic (all existing signals, no added flip-flops):
    //   bit3 aseen  C5 page engine ever saw a frame
    //   bit2 bseen  C6 page engine ever saw a frame
    //   bit1 local_fault
    //   bit0 af|bf  page engine fault
    // Cause split for local_fault (sticky, cleared with the merge reset).
    reg ar_bad, ae_bad;
    always @(posedge o_clk or negedge o_rst_n)
        if (!o_rst_n) begin ar_bad<=1'b0; ae_bad<=1'b0; end
        else if (state==WAIT_ROW && av && !ac && !bc) begin
            if (ar!=y) ar_bad<=1'b1;
            if (y!=0 && ae!=frame_a) ae_bad<=1'b1;
        end
    assign fault_src = {aseen, bseen, (ar_bad|ae_bad), local_fault};

    // Drain outside B's output region, including the long A inter-frame wait
    // at y==0. Keep ordinary row waits intact. 4096 o_clk = 65.5 us exceeds
    // normal inter-row slack but stays below the B ring/FIFO fill budget.
    // Once A is available, stop this gap drain and accept A after any pending
    // consume pulse retires. Never drain a page while its pixels are in use.
    // Every displayed native page is consumed once. A count of pages consumed
    // in the previous output frame is phase/overlap dependent, not a source
    // cadence estimate; feeding it back can stall this two-page ring.
    // Retain diagnostic names for the unchanged longrun probe.
    wire [9:0] b_rate = 10'd480;
    reg [9:0] b_seen;
    wire b_drain = bv && !bc && ((y>=B_HEIGHT) ||
        (state==WAIT_ROW && y==0 && !av && wait_count>=4096));


    always @(*) begin
        addr_a=(x<SLOT_WIDTH) ? x[10:0] : 11'd0;
        addr_b=(x>=SLOT_WIDTH && x<SLOT_WIDTH+B_WIDTH) ? x-SLOT_WIDTH : 11'd0;
    end
    always @(posedge o_clk or negedge o_rst_n)
        if (!o_rst_n) begin
            c_data<=0; c_de<=0; c_vs<=0; frame_complete<=0; b_missing<=0;
            state<=VSYNC; blank_count<=0; x<=0; y<=0; frame_a<=0; frame_b<=0;
            use_b<=0; local_fault<=0; wait_count<=0; ac<=0; bc<=0; b_any<=0;
            b_seen<=10'd0;
            b_started<=0;
        end else begin
            ac<=0; bc<=0; c_de<=0; c_vs<=0; frame_complete<=0;
            if (fault) begin state<=FAILED; c_data<=0; end
            else case (state)
            WAIT_ROW: begin
                wait_count<=wait_count+1;
                if (wait_count==ROW_TIMEOUT-1) local_fault<=1;
                // C5 is the master. C6's frames free-run, so the inter-camera
                // phase is an arbitrary constant (cam_phase_mon reports it).
                // Requiring "B row y of the frame pinned at y==0" deadlocks as
                // soon as that constant exceeds the two-slot page ring, which
                // is what killed every 720p attempt.
                // Never wait for C6: with HTS=3800 a C5 line is 45.2 us and a
                // merge row is 41.0 us, so waiting can push a row past the line
                // time and overwrite C5's two-slot page ring (ar!=y). Taking A
                // as soon as it is ready keeps the merge strictly faster; C6 is
                // used when its page happens to be there and that camera's
                // phase offset shows up as a constant vertical shift.
                if (b_drain) bc<=1;                   // consume unplaceable pages
                if (bv) begin b_started<=1'b1; b_any<=1'b1; end  // C6 delivered
                if (av && !ac && !bc && !b_drain) begin
                    if (ar!=y || (y!=0 && ae!=frame_a)) local_fault<=1;
                    else begin
                        if (y==0) begin
                            frame_a<=ae;
                            frame_b<=bv ? be : blatest;
                            b_missing<=0;
                        end
                        use_b <= (y<B_HEIGHT) && bv;
                        x<=0; wait_count<=0; state<=PIXELS;
                    end
                end
            end
            PIXELS: begin
                c_de<=1;
                if (x<A_WIDTH && y<A_HEIGHT) c_data<=ad;
                else if (x>=SLOT_WIDTH && x<SLOT_WIDTH+B_WIDTH && use_b) c_data<=bd;
                else c_data<=0;
                if (x==2*SLOT_WIDTH-1) begin
                    ac<=1;
                    if (use_b) begin
                        bc<=1;
                        if (b_seen != 10'd1023) b_seen <= b_seen + 10'd1;
                    end
                    state<=GAP;
                end else x<=x+1'b1;
            end
            GAP: begin
                if (y==OUT_HEIGHT-1) begin
                    // Fail closed if C6 delivered nothing at all this frame: a
                    // phase offset is tolerated, a dead camera is not.
                    if (!b_any) local_fault<=1;
                    else frame_complete<=1;
                    b_seen<=10'd0;
                    b_any<=1'b0;
                    state<=VSYNC;
                end else begin y<=y+1'b1; state<=WAIT_ROW; end
            end
            VSYNC: begin
                if (bv && !bc) begin bc<=1; b_any<=1'b1; end  // drain + alive
                c_vs<=blank_count>=6250;
                blank_count<=blank_count+1'b1;
                if (blank_count==6313) begin
                    blank_count<=0; y<=0; state<=WAIT_ROW;
                    b_started<=1'b0;   // re-acquire the C6 phase
                end
            end
            FAILED: c_data<=0;
            default: local_fault<=1;
            endcase
        end
endmodule


// ---------------------------------------------------------------------------
// Inter-camera frame phase monitor (diagnostic, C5 pixel-clock domain).
//
// Counts C5's active lines between C5's SOF and C6's SOF. Both sensors run the
// same 984-line frame at the same line period, so this count IS the row offset
// between their frames. No reset on purpose: capture_hold must not wipe the
// measurement. `code` is quasi-static (updated once per frame).
// ---------------------------------------------------------------------------
module cam_phase_mon #(parameter SAT=60)(
    input a_clk, input a_vs, input a_de,   // C5 (p1 domain)
    input b_vs,                            // C6 VS, asynchronous
    output reg [3:0] code
);
    reg a_vs_d, a_de_d;
    reg [10:0] lines;
    reg [2:0] b_vs_s;
    wire a_sof  = a_vs && !a_vs_d;
    wire a_line = a_de && !a_de_d;
    wire b_sof  = b_vs_s[2] && !b_vs_s[1];

    initial code = 4'hF;

    always @(posedge a_clk) begin
        a_vs_d <= a_vs;
        a_de_d <= a_de;
        b_vs_s <= {b_vs_s[1:0], b_vs};
        if (a_sof)        lines <= 11'd0;
        else if (a_line)  lines <= lines + 1'b1;
        if (b_sof)        code <= (lines >= SAT) ? 4'hF : {2'b00, lines[5:2]};
    end
endmodule
