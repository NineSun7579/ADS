// AXI-clock motion snapshot aperture, offsets within 0x20000b00..0x20000bff.
// records[camera*320 +: 320], camera=0..5. Original ten little-endian words:
// 0 sequence; 1 flags (reference/comparison valid, bbox valid, frame error);
// 2 {8'b0, samples[15:0], blocks[7:0]}; 3 inclusive bbox nibbles
// {16'b0, maxy, miny, maxx, minx}; 4..9 bitmap[191:0], row-major.
// Selector: [10:8] camera, [3:0] word; bit31 is a write-only capture pulse.
// Strobed selector bytes are merged BEFORE capture. Invalid camera capture
// leaves snapshot/generation intact. Invalid camera reads return zero.
// A valid camera capture freezes sixteen words: ten original + six metadata.
// Geometry +40: height[31:16], width[15:0] = 0x01e00280.
// Config +50: rows[31:24], cols[23:16], block[15:8], stride[7:0]
// = 0x0c102804 (12 rows, 16 columns, 40-pixel block, sample stride 4).
module motion_register_bank (
    input wire clk,
    input wire rst_n,
    input wire [1919:0] motion_records,
    input wire [1151:0] frame_metadata,
    input wire wr_en,
    input wire [7:0] wr_offset,
    input wire [31:0] wr_data,
    input wire [3:0] wr_strb,
    input wire [7:0] rd_offset,
    output reg [31:0] rd_data
);
    reg [3:0] word_index;
    reg [2:0] camera_index;
    reg [511:0] snapshot;
    reg [31:0] generation;
    // Three-stage write: (1) register the decoded selector write, (2) merge
    // strobed selector bytes, (3) capture the selected camera. The old single
    // cycle prep_regs aw_addr decode -> 316 CE and lease -> 6-way 512-bit mux
    // paths failed setup. Selector/snapshot/generation update 1-2 clocks after
    // the write handshake; the host cannot read in between.
    reg sel_wr;
    reg [31:0] sel_data;
    reg [3:0] sel_strb;
    reg cap_pending;
    reg [2:0] cap_camera;
    wire [3:0] next_word = sel_strb[0] ? sel_data[3:0] : word_index;
    wire [2:0] next_camera = sel_strb[1] ? sel_data[10:8] : camera_index;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sel_wr <= 0;
            sel_data <= 0;
            sel_strb <= 0;
            word_index <= 0;
            camera_index <= 0;
            cap_pending <= 0;
            cap_camera <= 0;
            snapshot <= 0;
            generation <= 0;
        end else begin
            sel_wr <= wr_en && wr_offset == 8'h00;
            sel_data <= wr_data;
            sel_strb <= wr_strb;
            cap_pending <= 0;
            if (sel_wr) begin
                word_index <= next_word;
                camera_index <= next_camera;
                cap_pending <= sel_strb[3] && sel_data[31] && next_camera < 6;
                cap_camera <= next_camera;
            end
            if (cap_pending) begin
                snapshot <= {frame_metadata[cap_camera*192 +: 192], motion_records[cap_camera*320 +: 320]};
                generation <= generation + 1'b1;
            end
        end
    end

    always @* begin
        case (rd_offset)
            8'h00: rd_data = {21'd0, camera_index, 4'd0, word_index};
            8'h10: rd_data = (camera_index < 6) ?
                             snapshot[word_index*32 +: 32] : 32'd0;
            8'h20: rd_data = generation;
            8'h30: rd_data = 32'h4d4f5431;
            8'h40: rd_data = 32'h01e00280;
            8'h50: rd_data = 32'h0c102804;
            8'h60: rd_data = 32'h00010010; // extension version 1, 16 words
            default: rd_data = 0;
        endcase
    end
endmodule
