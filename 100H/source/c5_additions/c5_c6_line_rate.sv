// [DIAG 2026-10-22] C6 line-rate measurement for the merged SFP raster.
//
// c5_raster_split_pipe drives ONE merged raster: vs6/hs6 come from the same
// symbol as vs5/hs5, so there is no independent C6 HS.  A "C6 line" is therefore
// defined as a raster row in which de6 was asserted at least once - i.e. a row
// that actually carried native C6 pixels (x in [split, split+640), y < 480).
//
//   lines_per_frame : number of such rows between two merged VS rising edges.
//                     This is the receiver-side equivalent of the host-visible
//                     "N of C6's 480 rows carry data" number.
//   line_cycles     : axi_clk cycles between two consecutive such rows, i.e.
//                     C6's own line period as observed here (last measured).
//
// Strictly read-only: it consumes vs/hs/de and drives nothing else, so the
// raster, split, writer and fault logic are unaffected.
module c5_c6_line_rate(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        vs,
    input  wire        hs,
    input  wire        de,
    output wire [31:0] lines_per_frame,
    output wire [31:0] line_cycles
);
    reg        hs_d, vs_d, de_seen;
    reg [15:0] rows;
    reg [31:0] rows_lat, gap, cnt;
    wire hs_rise = hs && !hs_d;
    wire vs_rise = vs && !vs_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hs_d <= 1'b0; vs_d <= 1'b0; de_seen <= 1'b0;
            rows <= 16'd0; rows_lat <= 32'd0; gap <= 32'd0; cnt <= 32'd0;
        end else begin
            hs_d <= hs;
            vs_d <= vs;
            if (de) de_seen <= 1'b1;
            // Saturate instead of wrapping so a stale reading stays readable.
            if (!(hs_rise && de_seen) && cnt != 32'hffff_ffff) cnt <= cnt + 1'b1;
            if (vs_rise) begin
                // A row still open at the frame edge belongs to this frame.
                rows_lat <= {16'd0, rows} + (de_seen ? 32'd1 : 32'd0);
                rows     <= 16'd0;
                de_seen  <= 1'b0;
            end else if (hs_rise) begin
                if (de_seen) begin
                    rows <= rows + 16'd1;
                    gap  <= cnt + 1'b1;   // +1 for the edge the gap timer restarted on
                    cnt  <= 32'd0;
                end
                de_seen <= 1'b0;
            end
        end
    end

    assign lines_per_frame = rows_lat;
    assign line_cycles     = gap;
endmodule
