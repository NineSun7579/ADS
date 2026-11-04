// Solid/dashed classifier for one fitted lane. One row presence bit per clock
// (valid-gated), rows in order top..bottom. Gaps are counted only when closed
// by a later present row, so leading/trailing absence never counts as a gap.
// solid = present*5 >= span*4 (duty >= 0.80) && max_gap <= MAX_GAP.
module native_bev_dash_classifier #(parameter MAX_GAP = 20)(
    input wire clk,input wire rst,
    input wire clear,
    input wire row_valid,input wire row_present,
    output reg [8:0] present_rows,   // rows with a line
    output reg [8:0] span_rows,      // first..last present row, inclusive
    output reg [8:0] max_gap,
    output reg [8:0] segments,
    output wire solid,               // meaningful when present_rows != 0
    output wire seen
);
    reg [8:0] pending_gap;
    reg prev;
    assign seen = present_rows != 0;
    assign solid = seen &&
                   ({present_rows,2'b00}+present_rows >= {span_rows,2'b00}) &&
                   (max_gap <= MAX_GAP);
    always @(posedge clk) begin
        if (rst || clear) begin
            present_rows<=0; span_rows<=0; max_gap<=0; segments<=0;
            pending_gap<=0; prev<=0;
        end else if (row_valid) begin
            prev <= row_present;
            if (row_present) begin
                present_rows <= present_rows + 9'd1;
                if (!seen) span_rows <= 9'd1;
                else span_rows <= span_rows + pending_gap + 9'd1;
                if (pending_gap > max_gap) max_gap <= pending_gap;
                if (!prev) segments <= segments + 9'd1;
                pending_gap <= 0;
            end else if (seen) pending_gap <= pending_gap + 9'd1;
        end
    end
endmodule
