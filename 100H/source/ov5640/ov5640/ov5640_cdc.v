//��ʱ����
module ov5640_cdc #(
    parameter DATA_WIDTH = 24,
    parameter DEVICE = "PG"
)
(
    // [CDC_PIXEL] Read-only per-frame snapshots, all in video_clk domain.
    output reg [31:0] dbg_cdc_input,
    output reg [31:0] dbg_cdc_output,
    output reg [31:0] dbg_cdc_drop,
    output reg [31:0] dbg_cdc_seq,
    input         cam_clk    /*synthesis PAP_MARK_DEBUG="1"*/,          //???????
    input         cam_rst    /*synthesis PAP_MARK_DEBUG="1"*/,

    input [DATA_WIDTH-1 : 0]   s_data     /*synthesis PAP_MARK_DEBUG="1"*/,
    input                      s_valid    /*synthesis PAP_MARK_DEBUG="1"*/,
    input                      s_hsync    /*synthesis PAP_MARK_DEBUG="1"*/,
    input                      s_vsync    /*synthesis PAP_MARK_DEBUG="1"*/,

    input                      video_clk  /*synthesis PAP_MARK_DEBUG="1"*/,
    input                      video_rst  /*synthesis PAP_MARK_DEBUG="1"*/,
    output [DATA_WIDTH-1 : 0]  video_data /*synthesis PAP_MARK_DEBUG="1"*/,
    output                     video_valid/*synthesis PAP_MARK_DEBUG="1"*/,
    output                     video_hsync/*synthesis PAP_MARK_DEBUG="1"*/,
    output                     video_vsync/*synthesis PAP_MARK_DEBUG="1"*/
);








    // reg s_vsync_d, s_hsync_d;
    // always @(posedge cam_clk) begin
    //     s_vsync_d <= s_vsync;
    //     s_hsync_d <= s_hsync;
    // end
    // wire vsync_rise = s_vsync & ~s_vsync_d;
    // wire hsync_rise = s_hsync & ~s_hsync_d;





    // reg [31 : 0] cnt_cdc_in/*synthesis PAP_MARK_DEBUG="1"*/;
    // always @(posedge cam_clk) begin
    //     if(cam_rst)begin
    //         cnt_cdc_in <= 32'd0;
    //     end
    //     else if(vsync_rise)begin
    //         cnt_cdc_in <= 32'd0;
    //     end
    //     else if(s_valid)begin
    //         cnt_cdc_in <= cnt_cdc_in + 32'd1;
    //     end
    // end


    // reg [31 : 0] cnt_cdc_in_h/*synthesis PAP_MARK_DEBUG="1"*/;
    // always @(posedge cam_clk) begin
    //     if(cam_rst)begin
    //         cnt_cdc_in_h <= 32'd0;
    //     end
    //     else if(hsync_rise)begin
    //         cnt_cdc_in_h <= 32'd0;
    //     end
    //     else if(s_valid)begin
    //         cnt_cdc_in_h <= cnt_cdc_in_h + 32'd1;
    //     end
    // end

    // reg not_1920/*synthesis PAP_MARK_DEBUG="1"*/;
    // always @(posedge cam_clk) begin
    //     if(cam_rst)begin
    //         not_1920 <= 1'b0;
    //     end        
    //     else if(vsync_rise) begin
    //         not_1920 <= 1'b0;
    //     end
    //     else if(cnt_cdc_in_h != 32'd1920 && hsync_rise && cnt_cdc_in_h != 32'd0)begin
    //         not_1920 <= 1'b1;
    //     end
    // end



    // [FIX 2026-09-18] The original code pushed {vsync,href} through a FIFO whose
    // write-enable was `(|vhsync_in) | s_valid`. That never records the LOW phase
    // of hsync/vsync, so the read side saw a scrambled, glitchy sync stream
    // (measured vsync at ~6x the true frame rate). The spurious vsync resets
    // ov5640_ddr_w axi_cnt mid-frame, so axi_data_last never fired, no frame ever
    // completed and the write engine streamed garbage forever.
    //
    // vsync/hsync are slow single-bit levels here (a vsync pulse spans thousands of
    // cam_pclk cycles, far more than 2 video_clk cycles), so a plain 2-stage
    // synchroniser is both simpler and correct. The pixel data keeps using the
    // asynchronous FIFO below; only the sync levels change.
    reg [1:0] vsync_sync, hsync_sync;
    always @(posedge video_clk) begin
        if (video_rst) begin
            vsync_sync <= 2'b0;
            hsync_sync <= 2'b0;
        end
        else begin
            vsync_sync <= {vsync_sync[0], s_vsync};
            hsync_sync <= {hsync_sync[0], s_hsync};
        end
    end

    assign video_hsync = hsync_sync[1];
    assign video_vsync = vsync_sync[1];

















    wire empty;
    wire full ;
    wire rd_rst_busy;
    wire wr_rst_busy;
    wire data_valid ;
    wire wr_en;
    wire rd_en;

    wire [DATA_WIDTH-1 : 0] dout;


    wire [DATA_WIDTH-1 : 0] din = s_data;
    assign wr_en = !full & s_valid;

    assign rd_en       = !empty;
    assign video_data  = dout[DATA_WIDTH-1 : 0];




    reg video_valid_r;
    always @(posedge video_clk) begin
        if (video_rst) video_valid_r <= 1'b0;
        else video_valid_r <= rd_en;
    end
    assign video_valid = video_valid_r;
    ov5640_cdc_fifo ov5640_cdc_fifo (
      .wr_clk(cam_clk),                // input
      .wr_rst(cam_rst),                // input
      .wr_en(wr_en),                  // input
      .wr_data(din),              // input [24:0]
      .wr_full(full),              // output
    
      .rd_clk(video_clk),                // input
      .rd_en(rd_en),                  // input
      .rd_data(dout),              // output [24:0]
      .rd_empty(empty),            // output
      .rd_rst(video_rst),                // input
      .almost_full(),      // output
      .almost_empty()     // output
    );





    // wire video_vsync_rise = vsync_d & ~vsync_dd;
    // wire video_hsync_rise = hsync_d & ~hsync_dd;


    // reg [31 : 0] cnt_cdc_out/*synthesis PAP_MARK_DEBUG="1"*/;
    // always @(posedge video_clk) begin   
    //     if(video_rst)begin
    //         cnt_cdc_out <= 32'd0;
    //     end
    //     else if(video_vsync_rise)begin
    //         cnt_cdc_out <= 32'd0;
    //     end
    //     else if(video_valid)begin
    //         cnt_cdc_out <= cnt_cdc_out + 32'd1;
    //     end
    // end


    // reg [31 : 0] cnt_cdc_out_h/*synthesis PAP_MARK_DEBUG="1"*/;
    // always @(posedge video_clk) begin
    //     if(video_rst)begin
    //         cnt_cdc_out_h <= 32'd0;
    //     end
    //     else if(video_hsync_rise)begin
    //         cnt_cdc_out_h <= 32'd0;
    //     end
    //     else if(video_valid)begin
    //         cnt_cdc_out_h <= cnt_cdc_out_h + 32'd1;
    //     end
    // end



    // Diagnostic-only source snapshot: data is held for a complete frame.
    // Two data stages precede the three-stage toggle notification. This is
    // a bundled-data transfer, not a live asynchronous binary counter read.
    // Diagnostic observation stage removes falling-to-rising counter CE path.
    // Frame boundary, valid and FIFO-drop event are delayed together.
    (* syn_maxfan = 8 *) reg diag_vs;
    reg diag_valid, diag_drop;
    always @(posedge cam_clk or posedge cam_rst) begin
        if (cam_rst) begin
            diag_vs <= 0; diag_valid <= 0; diag_drop <= 0;
        end else begin
            diag_vs <= s_vsync;
            diag_valid <= s_valid;
            diag_drop <= s_valid && full;
        end
    end
    reg src_vs_q, src_toggle;
    reg [31:0] src_count, src_drop, src_seq;
    reg [95:0] src_snapshot;
    always @(posedge cam_clk or posedge cam_rst) begin
        if (cam_rst) begin
            src_vs_q <= 0;
            src_toggle <= 0;
            src_count <= 0;
            src_drop <= 0;
            src_seq <= 0;
            src_snapshot <= 0;
        end else begin
            src_vs_q <= diag_vs;
            if (diag_vs && !src_vs_q) begin
                src_snapshot <= {src_seq + 32'd1, src_drop, src_count};
                src_toggle <= ~src_toggle;
                src_seq <= src_seq + 1'b1;
                src_count <= {31'd0, diag_valid};
                src_drop <= {31'd0, diag_drop};
            end else begin
                if (diag_valid) src_count <= src_count + 1'b1;
                if (diag_drop) src_drop <= src_drop + 1'b1;
            end
        end
    end

    reg [95:0] snapshot_s1, snapshot_s2;
    reg [2:0] toggle_sync;
    reg toggle_seen, out_vs_q;
    reg [31:0] out_count, out_snapshot;
    always @(posedge video_clk) begin
        if (video_rst) begin
            snapshot_s1 <= 0;
            snapshot_s2 <= 0;
            toggle_sync <= 0;
            toggle_seen <= 0;
            out_vs_q <= 0;
            out_count <= 0;
            out_snapshot <= 0;
            dbg_cdc_input <= 0;
            dbg_cdc_output <= 0;
            dbg_cdc_drop <= 0;
            dbg_cdc_seq <= 0;
        end else begin
            snapshot_s1 <= src_snapshot;
            snapshot_s2 <= snapshot_s1;
            toggle_sync <= {toggle_sync[1:0], src_toggle};
            out_vs_q <= video_vsync;
            if (video_vsync && !out_vs_q) begin
                out_snapshot <= out_count;
                out_count <= {31'd0, video_valid};
            end else if (video_valid) out_count <= out_count + 1'b1;
            if (toggle_sync[2] != toggle_seen) begin
                toggle_seen <= toggle_sync[2];
                dbg_cdc_input <= snapshot_s2[31:0];
                dbg_cdc_drop <= snapshot_s2[63:32];
                dbg_cdc_seq <= snapshot_s2[95:64];
                dbg_cdc_output <= out_snapshot;
            end
        end
    end

endmodule