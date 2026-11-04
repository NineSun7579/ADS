`timescale 1ns/1ps
// Machine-readable heartbeat. rst_n must assert in both clock domains together.
// request/status belong to out_clk; debug inputs belong to pclk. No format gate.
// Words, least significant first:
// 0: 00050703 (reserved=0, source=5, kind=7, type=3)
// 1: sequence[31:16], status[15:8], fresh[7], request[6], flags[5:0]
// 2: rows[31:16], first width[15:0]; 3: max[31:16], min[15:0]
// 4: observed VS-toggle transitions (modulo 2^32), global-reset lifetime.
// fresh means at least one coherent snapshot arrived since last publication;
// it clears after pclk stops and the last in-flight snapshot drains.
module cam5_native_diag_sender #(
    parameter integer PERIOD_CYCLES=31250000
)(
    input wire pclk,input wire out_clk,input wire rst_n,
    input wire request,input wire [7:0] status,
    input wire [12:0] dbg_v0,dbg_v1,dbg_v2,dbg_v3,
    input wire [5:0] dbg_flags,input wire dbg_vs_toggle,
    output reg diag_valid,input wire diag_ready,output reg [159:0] diag_payload
);
    localparam integer TIMER_WIDTH=PERIOD_CYCLES<2 ? 1 : $clog2(PERIOD_CYCLES);
    localparam integer TIMER_LIMIT=PERIOD_CYCLES<2 ? 0 : PERIOD_CYCLES-1;
    wire [89:0] snapshot;
    wire snapshot_valid;
    reg [89:0] latest;
    reg fresh;
    reg [31:0] vs_count;
    reg vs_previous,vs_initialized;
    reg [15:0] report_sequence;
    reg [TIMER_WIDTH-1:0] timer;
    // Common asynchronous assertion preserves toggle-protocol reset pairing;
    // each domain releases only after two local edges, even if pclk was absent.
    wire p_rst_n,out_rst_n;
    video_reset_sync p_reset(.clk(pclk),.request_n(rst_n),.rst_n(p_rst_n));
    video_reset_sync out_reset(.clk(out_clk),.request_n(rst_n),.rst_n(out_rst_n));
    // Observe every pclk edge, not just each report: even frame counts must
    // not alias away. Seed the initial level without inventing a VS event.
    // Neither request nor format qualification resets this activity counter.
    always @(posedge pclk or negedge p_rst_n) begin
        if(!p_rst_n)begin vs_count<=0;vs_previous<=0;vs_initialized<=0;end
        else begin
            vs_previous<=dbg_vs_toggle;vs_initialized<=1;
            if(vs_initialized && dbg_vs_toggle!=vs_previous)vs_count<=vs_count+1'b1;
        end
    end
    cam5_bundle_cdc #(.WIDTH(90)) debug_cdc(
        .s_clk(pclk),.s_rst_n(p_rst_n),
        .s_data({vs_count,dbg_flags,dbg_v3,dbg_v2,dbg_v1,dbg_v0}),
        .s_valid(1'b1),.s_ready(),.d_clk(out_clk),.d_rst_n(out_rst_n),
        .d_data(snapshot),.d_valid(snapshot_valid),.d_ready(1'b1));
    always @(posedge out_clk or negedge out_rst_n) begin
        if(!out_rst_n) begin
            latest<=0;fresh<=0;report_sequence<=0;timer<=0;
            diag_valid<=0;diag_payload<=0;
        end else begin
            if(timer<TIMER_LIMIT)timer<=timer+1'b1;
            if(snapshot_valid)begin latest<=snapshot;fresh<=1;end
            // Hold the entire packet stable under backpressure. Restart the
            // interval at acceptance, preventing queued catch-up bursts.
            if(diag_valid && diag_ready)begin diag_valid<=0;timer<=0;end
            if(!diag_valid && timer==TIMER_LIMIT)begin
                diag_valid<=1;report_sequence<=report_sequence+1'b1;
                diag_payload<={latest[89:58],
                    3'd0,latest[38:26],3'd0,latest[51:39],
                    3'd0,latest[25:13],3'd0,latest[12:0],
                    report_sequence,status,fresh,request,latest[57:52],32'h00050703};
                // A snapshot arriving on this edge belongs to the next report.
                fresh<=snapshot_valid;
            end
        end
    end
endmodule
