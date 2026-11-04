// 0x2000_0180..0x2000_01A4 lane ROI AXI-Lite control/status.
// Independent slave; prep_regs ignores this exact address interval.
module lane_roi_regs (
    input wire clk, input wire rst_n,
    input wire s_axi_awvalid, output reg s_axi_awready,
    input wire [31:0] s_axi_awaddr,
    input wire s_axi_wvalid, output reg s_axi_wready,
    input wire [31:0] s_axi_wdata, input wire [3:0] s_axi_wstrb,
    output reg s_axi_bvalid, input wire s_axi_bready,
    input wire s_axi_arvalid, output reg s_axi_arready,
    input wire [31:0] s_axi_araddr,
    output reg s_axi_rvalid, input wire s_axi_rready,
    output reg [31:0] s_axi_rdata,
    output reg lane_enable,
    output reg [7:0] lane_white_min, output reg [7:0] lane_white_span,
    output reg [7:0] lane_min_run, output reg [3:0] lane_line_width,
    input wire [15:0] cam1_left_count, input wire [15:0] cam1_right_count,
    input wire [31:0] cam1_frame_sequence,
    input wire cam1_left_valid, input wire cam1_right_valid,
    input wire [15:0] hdmi_left_count, input wire [15:0] hdmi_right_count,
    input wire [31:0] hdmi_frame_sequence,
    input wire hdmi_left_valid, input wire hdmi_right_valid
);
    reg aw_seen, w_seen, ar_accepted;
    reg [31:0] aw_addr, ar_addr, w_data;
    reg [3:0] w_strb;
    wire wr_fire = aw_seen && w_seen && !s_axi_bvalid;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_awready <= 0; s_axi_wready <= 0; s_axi_bvalid <= 0;
            aw_seen <= 0; w_seen <= 0; aw_addr <= 0; w_data <= 0; w_strb <= 0;
            lane_enable <= 0; lane_white_min <= 180; lane_white_span <= 45;
            lane_min_run <= 12; lane_line_width <= 2;
        end else begin
            s_axi_awready <= 0; s_axi_wready <= 0;
            if (s_axi_bvalid && s_axi_bready) s_axi_bvalid <= 0;
            if (!aw_seen && !s_axi_bvalid && s_axi_awvalid && !s_axi_awready) begin
                s_axi_awready <= 1; aw_addr <= s_axi_awaddr; aw_seen <= 1;
            end
            if (!w_seen && !s_axi_bvalid && s_axi_wvalid && !s_axi_wready) begin
                s_axi_wready <= 1; w_data <= s_axi_wdata; w_strb <= s_axi_wstrb; w_seen <= 1;
            end
            if (wr_fire) begin
                aw_seen <= 0; w_seen <= 0; s_axi_bvalid <= 1;
                case (aw_addr[7:0])
                    8'h80: if (w_strb[0]) lane_enable <= w_data[0];
                    8'h84: begin
                        if (w_strb[0]) lane_white_min <= w_data[7:0];
                        if (w_strb[1]) lane_white_span <= w_data[15:8];
                        if (w_strb[2]) lane_min_run <= w_data[23:16];
                        if (w_strb[3] && w_data[27:24] <= 7)
                            lane_line_width <= w_data[27:24];
                    end
                    default: ;
                endcase
            end
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_arready <= 0; s_axi_rvalid <= 0; s_axi_rdata <= 0;
            ar_addr <= 0; ar_accepted <= 0;
        end else begin
            s_axi_arready <= 0;
            ar_accepted <= s_axi_arvalid && !s_axi_rvalid && !s_axi_arready;
            if (s_axi_arvalid && !s_axi_rvalid && !s_axi_arready) begin
                s_axi_arready <= 1; ar_addr <= s_axi_araddr;
            end
            if (ar_accepted) begin
                s_axi_rvalid <= 1;
                case (ar_addr[7:0])
                    8'h80: s_axi_rdata <= {31'd0,lane_enable};
                    8'h84: s_axi_rdata <= {4'd0,lane_line_width,lane_min_run,lane_white_span,lane_white_min};
                    8'h88: s_axi_rdata <= {cam1_right_count,cam1_left_count};
                    8'h8c: s_axi_rdata <= cam1_frame_sequence;
                    8'h90: s_axi_rdata <= {hdmi_right_count,hdmi_left_count};
                    8'h94: s_axi_rdata <= hdmi_frame_sequence;
                    8'h98: s_axi_rdata <= {28'd0,hdmi_right_valid,hdmi_left_valid,cam1_right_valid,cam1_left_valid};
                    8'h9c: s_axi_rdata <= {8'd1,12'd360,12'd640};
                    8'ha0: s_axi_rdata <= {16'd480,16'd640};
                    8'ha4: s_axi_rdata <= {16'd480,16'd1280};
                    default: s_axi_rdata <= 0;
                endcase
            end else if (s_axi_rvalid && s_axi_rready) s_axi_rvalid <= 0;
        end
    end
endmodule
