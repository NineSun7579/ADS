module ov5640_ddr_w #(
    parameter DATA_WIDTH = 24,
    parameter AXI_DATA_WIDTH = 128,
    parameter CAM_DATA_LEN  = 172800, //1280*720*3/16
    parameter DEVICE = "PG"
)(
    input          axi_clk        ,
    input          axi_rst        ,
    input          capture_flush,
    output         capture_overflow,
    output [15:0] axi_data_available,


    input  [$clog2(CAM_DATA_LEN) : 0]  data_len       /*synthesis PAP_MARK_DEBUG="1"*/, //��16�ֽ�Ϊ��λ

    input  [DATA_WIDTH-1 :0]       s_data       ,
    input                          s_data_valid ,
    input                          s_vsync      ,
    input                          s_hsync      ,       //û��

    output [AXI_DATA_WIDTH-1 : 0]  axi_data       /*synthesis PAP_MARK_DEBUG="1"*/,
    output                         axi_data_valid /*synthesis PAP_MARK_DEBUG="1"*/,
    output                         axi_data_last  /*synthesis PAP_MARK_DEBUG="1"*/, 
    input                          axi_data_ready /*synthesis PAP_MARK_DEBUG="1"*/,
    output [31:0]                  dbg_axi_cnt,
    output [31:0]                  dbg_axi_num  ,
    // [ZDIAG 2026-09-18] per-frame zero-beat accounting, latched at VSYNC so
    // it can be read reliably once streaming stops.
    output [31:0]                  dbg_zdin     ,  // wr_en && din==0
    output [31:0]                  dbg_zout         // fifo_we && fifo_wd==0
);




    wire local_rst = axi_rst | capture_flush;
    wire out_full;
    reg             wr_en;
    reg  [31 : 0]   din  ;
    wire            rd_en;
    wire [AXI_DATA_WIDTH-1 : 0] dout ;

    wire                        empty;
    wire                        full /*synthesis PAP_MARK_DEBUG="1"*/;



    reg [1 : 0] cnt;
    always @(posedge axi_clk) begin
        if(local_rst)begin
            cnt <= 2'd0;
        end
        else if(s_data_valid)begin
            cnt <= cnt + 2'd1;
        end
    end
generate
    if(DATA_WIDTH == 24) begin    
    
        reg [23 : 0]  cam_data_temp;
        always @(posedge axi_clk) begin
            if(s_data_valid)begin
                case (cnt)
                    2'b00:begin
                        cam_data_temp <= s_data;
                    end
                    2'b01:begin
                        cam_data_temp <= {8'd0, s_data[23:8]};
                    end
                    2'b10:begin
                        cam_data_temp <= {16'd0, s_data[23:16]};
                    end
                    2'b11:begin
                        cam_data_temp <= 24'd0;
                    end
                endcase
            end
        end

        always @(posedge axi_clk) begin
            if(s_data_valid)begin
                case (cnt)
                    2'b01:begin
                        din <= {s_data[7:0], cam_data_temp[23:0]};
                    end
                    2'b10:begin
                        din <= {s_data[15:0], cam_data_temp[15:0]};
                    end
                    2'b11:begin
                        din <= {s_data, cam_data_temp[7:0]};
                    end
                endcase
            end
        end

        always @(posedge axi_clk) begin
            if(local_rst)begin
                wr_en <= 1'b0;
            end
            else if(s_data_valid & (cnt != 2'b00))begin
                wr_en <= 1'b1;
            end
            else begin
                wr_en <= 1'b0;
            end
        end

    end
    else if(DATA_WIDTH == 16) begin

        reg [15 : 0] cam_data_temp;
        always @(posedge axi_clk) begin
            if(s_data_valid) begin
                cam_data_temp <= s_data;
            end
        end


        always @(posedge axi_clk) begin
            if(s_data_valid)begin
                if(cnt[0]) begin
                    din <= {s_data, cam_data_temp};
                end
            end
        end

        always @(posedge axi_clk) begin
            if(local_rst)begin
                wr_en <= 1'b0;
            end
            else if(s_data_valid & cnt[0])begin
                wr_en <= 1'b1;
            end
            else begin
                wr_en <= 1'b0;
            end
        end

    end
    else if(DATA_WIDTH == 8) begin

        reg [23 : 0] cam_data_temp;
        always @(posedge axi_clk) begin
            if(s_data_valid) begin
                cam_data_temp <= {s_data, cam_data_temp[23:8]};
            end
        end

        always @(posedge axi_clk) begin
            if(s_data_valid)begin
                if(&cnt) begin
                    din <= {s_data, cam_data_temp};
                end
            end
        end


        always @(posedge axi_clk) begin
            if(local_rst)begin
                wr_en <= 1'b0;
            end
            else if(s_data_valid & &cnt)begin
                wr_en <= 1'b1;
            end
            else begin
                wr_en <= 1'b0;
            end
        end

    end
endgenerate






        reg [$clog2(CAM_DATA_LEN) : 0] axi_num/*synthesis PAP_MARK_DEBUG="1"*/;
        reg [$clog2(CAM_DATA_LEN) : 0] axi_cnt/*synthesis PAP_MARK_DEBUG="1"*/;

        always @(posedge axi_clk) begin
            if(local_rst)begin
                axi_num <= 20'd0;
            end
            else begin
                if(s_vsync) axi_num <= data_len - 20'd1;
            end
        end

        always @(posedge axi_clk) begin
            if(local_rst)begin
                axi_cnt <= 20'd0;
            end
            else if(s_vsync)begin
                axi_cnt <= 20'd0;
            end
            else if(axi_data_valid & axi_data_ready)begin
                if(axi_data_last)begin
                    axi_cnt <= 20'd0;
                end
                else begin
                    axi_cnt <= axi_cnt + 20'd1;
                end
            end
        end

    // reg test1/*synthesis PAP_MARK_DEBUG="1"*/;
    // always @(posedge axi_clk) begin
    //     if(axi_rst) begin
    //         test1 <= 1'b0;
    //     end
    //     else if(s_vsync && (axi_cnt != 0)) begin
    //         test1 <= 1'b1;
    //     end
    // end


    // The distributed FIFO is first-word fall-through with OUTPUT_REG=0:
    // dout already addresses the current head, and rd_en advances it only
    // after the AXI consumer accepts that word.
    assign rd_en = axi_data_valid & axi_data_ready;
    assign axi_data_last = (axi_cnt == axi_num);
    assign axi_data = dout;
    assign axi_data_valid = !empty && !local_rst;




        wire [AXI_DATA_WIDTH-1 : 0] dout_drm;
        wire                        empty_drm/*synthesis PAP_MARK_DEBUG="1"*/;  
        wire                        almost_full_drm;
        wire                        almost_full_out;
        // Do not drain the DRM FIFO unless both stages can accept the word.
        // Without almost_full_out the output FIFO fills during AXI stalls and
        // DRM words are silently dropped -> periodic 128-bit stripes.
        wire rd_en_drm = !(empty_drm | almost_full_out | local_rst);
        ov5640_ddr_fifo_DRM ov5640_ddr_fifo_DRM (
          .clk(axi_clk),                      // input
          .rst(local_rst),                      // input
          .wr_en(wr_en),                  // input
          .wr_data(din),              // input [31:0]
          .wr_full(full),              // output
          
          .rd_en(rd_en_drm),                  // input
          .rd_data(dout_drm),              // output [127:0]
          .rd_empty(empty_drm),            // output

          .almost_full(almost_full_drm),      // output
          .almost_empty()     // output
        );


        // reg rd_en_drm_d;
        // always @(posedge axi_clk) begin
        //     if(axi_rst) begin
        //         rd_en_drm_d <= 1'b0;
        //     end
        //     else begin
        //         rd_en_drm_d <= rd_en_drm;  
        //     end
        // end

        // DRM rd_data is valid one cycle after rd_en. Delay only the write
        // enable; dout_drm is aligned with wr_en_drm on that following cycle.
        reg wr_en_drm;
        always @(posedge axi_clk) begin
            if (local_rst) begin
                wr_en_drm <= 1'b0;
            end
            else begin
                wr_en_drm <= rd_en_drm;
            end
        end

        wire                     fifo_we  = wr_en_drm;
        wire [AXI_DATA_WIDTH-1:0] fifo_wd = dout_drm;

        ov5640_ddr_fifo ov5640_ddr_fifo (
          .clk(axi_clk),                      // input
          .rst(local_rst),                      // input
          .wr_en  (fifo_we ),                  // input
          .wr_data(fifo_wd ),              // input [127:0]
          .full(out_full),              // output
          

          .rd_en(rd_en),                  // input
          .rd_data(dout),              // output [127:0]
          .empty(empty),            // output

          .almost_full(almost_full_out),      // output
          .almost_empty()     // output
        );





    
    // Stored credits span BOTH existing FIFOs and the DRM read pipeline.
    // Count accepted 32-bit writes minus consumed AXI words; no new storage.
    // Counting only the 16-deep output FIFO would deadlock at almost_full=15
    // when the input is sparse and no DRM read is pending to fill slot 16.
    localparam CREDIT_WORDS_PER_BEAT = AXI_DATA_WIDTH / 32;
    reg [12:0] stored_words;
    always @(posedge axi_clk) begin
        if(local_rst) stored_words <= 0;
        else case ({(wr_en && !full), rd_en})
            2'b10: stored_words <= stored_words + 1'b1;
            2'b01: stored_words <= stored_words - CREDIT_WORDS_PER_BEAT;
            2'b11: stored_words <= stored_words - (CREDIT_WORDS_PER_BEAT-1);
            default: stored_words <= stored_words;
        endcase
    end
    assign axi_data_available = local_rst ? 16'd0 :
                                stored_words / CREDIT_WORDS_PER_BEAT;
    assign capture_overflow = !local_rst && ((wr_en && full) || (fifo_we && out_full));
    assign dbg_axi_cnt = axi_cnt;
    assign dbg_axi_num = axi_num;

    // [ZDIAG 2026-09-18] zero-beat accounting for the stripe hunt.
    reg [31:0] zdin_cnt, zout_cnt;
    reg [31:0] zdin_lat, zout_lat;
    always @(posedge axi_clk) begin
        if (axi_rst) begin
            zdin_cnt <= 32'd0;
            zout_cnt <= 32'd0;
            zdin_lat <= 32'd0;
            zout_lat <= 32'd0;
        end
        else begin
            if (wr_en   && (din      == {32{1'b0}})) zdin_cnt <= zdin_cnt + 32'd1;
            if (fifo_we && (fifo_wd  == {AXI_DATA_WIDTH{1'b0}})) zout_cnt <= zout_cnt + 32'd1;
            if (s_vsync) begin
                zdin_lat <= zdin_cnt;
                zout_lat <= zout_cnt;
                zdin_cnt <= 32'd0;
                zout_cnt <= 32'd0;
            end
        end
    end
    assign dbg_zdin = zdin_lat;
    assign dbg_zout = zout_lat;

endmodule
