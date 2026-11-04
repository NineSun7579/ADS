`timescale 1ns/1ps
// Reverse fabric -> configuration epoch, and verified response -> forward
// fabric. The response mailbox is acknowledged only after END was injected,
// so COMMIT cannot release pixels before RUNNING goes onto the wire.
module cam5_runtime #(
    parameter SCCB_DIV=125, CONFIG_TIMEOUT=250000000
)(
    input fab_clk, fab_rst_n, link_ok,
    input [31:0] rx_data, input [3:0] rx_k,
    input cfg_clk, cfg_rst_n, initial_en,
    output c5_scl, inout c5_sda, output c6_scl, inout c6_sda,
    output capture_hold, output mode720, output epoch_active,
    output [1:0] config_ok,
    input stream_fault, input [2:0] stream_detail,
    input [3:0] phase_code,
    input meta_valid, output meta_ready, input [31:0] frame_sequence,
    output control_valid, input control_ready,
    output [31:0] control_data, output [3:0] control_k,
    output [31:0] protocol_errors
);
    wire rx_valid;
    wire [159:0] rx_payload;
    c5_packet_rx #(.ALIGN_BYTES(1)) receiver(
        .clk(fab_clk),.rst_n(fab_rst_n),.link_ok(link_ok),
        .in_data(rx_data),.in_k(rx_k),.in_valid(1'b1),
        .out_valid(rx_valid),.out_payload(rx_payload),
        .error_count(protocol_errors),.packet_active());
    wire cmd_space, cmd_valid, cmd_ready;
    wire [40:0] cmd_data;
    reg overflow;
    wire actionable=rx_payload[15:8]==1 || rx_payload[15:8]==3;
    always @(posedge fab_clk or negedge fab_rst_n)
        if (!fab_rst_n) overflow<=0;
        else if (rx_valid && actionable && !cmd_space) overflow<=1;
    cam5_bundle_cdc #(.WIDTH(41)) commands(
        .s_clk(fab_clk),.s_rst_n(fab_rst_n),
        .s_data({rx_payload[63:32],rx_payload[24],rx_payload[15:8]}),
        .s_valid(rx_valid && actionable),.s_ready(cmd_space),
        .d_clk(cfg_clk),.d_rst_n(cfg_rst_n),.d_data(cmd_data),
        .d_valid(cmd_valid),.d_ready(cmd_ready));
    wire start, cfg_done5,cfg_done6,cfg_err5,cfg_err6,restart5,restart6;
    reg pending_start,sensor_start,config_launched;
    reg [2:0] launch_pipe;
    // A failed C5 write can report ERROR while C6 is still recovering from
    // soft reset. Queue the next request until BOTH sensor sequencers finish;
    // never interrupt a reset recovery or mistake old done/error for this SET.
    always @(posedge cfg_clk or negedge cfg_rst_n)
        if(!cfg_rst_n)begin
            pending_start<=0;sensor_start<=0;config_launched<=0;launch_pipe<=0;
        end else begin
            sensor_start<=0;launch_pipe<={launch_pipe[1:0],sensor_start};
            if(launch_pipe[2])config_launched<=1;
            if(start)begin pending_start<=1;config_launched<=0;launch_pipe<=0;end
            else if(pending_start && restart5 && restart6)begin
                sensor_start<=1;pending_start<=0;
            end
        end
    wire [15:0] width5,height5,width6,height6;
    wire [31:0] epoch, response_detail;
    assign epoch_active=epoch!=0;
    wire response_valid, response_ready;
    wire [7:0] response_type;
    // Fault attribution for the ERROR reply: 0x2500|{stream,!link,ovf,1}.
// Fab-domain status bits, one 2FF each into clk_25M (quasi-static).
(* ASYNC_REG="TRUE" *) reg [3:0] detail_s0, detail_s1;
always @(posedge cfg_clk or negedge cfg_rst_n) begin
    if(!cfg_rst_n) begin detail_s0<=4'd0; detail_s1<=4'd0; end
    // hd_fault (stream_detail[2]) -> report the measured phase offset;
    // otherwise report the remaining stream/link sources.
    else begin
        detail_s0<=stream_detail[2] ? phase_code
                                  : {stream_detail[1:0],!link_ok,1'b1};
        detail_s1<=detail_s0;
    end
end
wire [3:0] fault_detail=detail_s1;
(* ASYNC_REG="TRUE" *) reg [1:0] fault_sync;
    always @(posedge cfg_clk or negedge cfg_rst_n)
        if (!cfg_rst_n) fault_sync<=0;
        else fault_sync<={fault_sync[0],stream_fault || !link_ok || overflow};
    cam5_mode_control #(.TIMEOUT_CYCLES(CONFIG_TIMEOUT)) mode_control(
        .clk(cfg_clk),.rst_n(cfg_rst_n),.command_valid(cmd_valid),
        .command_ready(cmd_ready),.command_type(cmd_data[7:0]),
        .command_mode720(cmd_data[8]),.command_epoch(cmd_data[40:9]),
        .mode720(mode720),.epoch(epoch),.capture_hold(capture_hold),
        .config_start(start),.config_done(config_launched && cfg_done5 && cfg_done6),
        .config_error(config_launched && (cfg_err5 || cfg_err6 ||
            (cfg_done6 && (width6!=640 || height6!=480)))),
        .actual_width(width5),.actual_height(height5),
        .transport_fault(fault_sync[1]),.fault_detail(fault_detail),.ready(),.failed(),
        .response_valid(response_valid),.response_ready(response_ready),
        .response_type(response_type),.response_detail(response_detail));
    reg_config_c5 #(.SCCB_DIV(SCCB_DIV)) c5_config(
        .clk_25M(cfg_clk),.camera_rstn(cfg_rst_n),.initial_en(initial_en),
        .start(sensor_start),.mode720(mode720),.timing720(mode720),.reg_conf_done(cfg_done5),
        .config_error(cfg_err5),.actual_width(width5),.actual_height(height5),
        .i2c_sclk(c5_scl),.i2c_sdat(c5_sda),.reg_index(),.restart_ready(restart5));
    reg_config_c5 #(.SCCB_DIV(SCCB_DIV)) c6_config(
        .clk_25M(cfg_clk),.camera_rstn(cfg_rst_n),.initial_en(initial_en),
        .start(sensor_start),.mode720(1'b0),.timing720(mode720),.reg_conf_done(cfg_done6),
        .config_error(cfg_err6),.actual_width(width6),.actual_height(height6),
        .i2c_sclk(c6_scl),.i2c_sdat(c6_sda),.reg_index(),.restart_ready(restart6));
    assign config_ok={cfg_done6 && !cfg_err6,cfg_done5 && !cfg_err5};
    // ABI header describes requested geometry, including ERROR packets. READY
    // is emitted only after the actual independent readbacks match it.
    wire [15:0] requested_width=mode720 ? 16'd1280 : 16'd640;
    wire [15:0] requested_height=mode720 ? 16'd720 : 16'd480;
    wire [159:0] response_payload={response_detail,16'd480,16'd640,
        requested_height,requested_width,epoch,7'd0,mode720,8'd5,response_type,8'd1};
    wire response_fab_valid, response_fab_ack;
    wire [159:0] response_fab;
    wire response_space;
    reg response_submitted;
    assign response_ready=response_submitted && response_space;
    always @(posedge cfg_clk or negedge cfg_rst_n)
        if (!cfg_rst_n) response_submitted<=0;
        else if (!response_valid) response_submitted<=0;
        else if (!response_submitted && response_space) response_submitted<=1;
    cam5_bundle_cdc #(.WIDTH(160)) responses(
        .s_clk(cfg_clk),.s_rst_n(cfg_rst_n),.s_data(response_payload),
        .s_valid(response_valid && !response_submitted),.s_ready(response_space),
        .d_clk(fab_clk),.d_rst_n(fab_rst_n),.d_data(response_fab),
        .d_valid(response_fab_valid),.d_ready(response_fab_ack));
    // response_ready above must mean transmission completion, not mailbox
    // space. The source ready becomes true again only after the returned ACK.
    reg response_seen;
    reg [159:0] effective;
    reg sending, sending_response, saw_wire;
    wire tx_space;
    wire choose_response=response_fab_valid && !response_seen;
    wire choose_meta=meta_valid && !choose_response && effective[63:32]!=0;
    wire tx_request=!sending && (choose_response || choose_meta);
    wire [159:0] meta_payload={frame_sequence,effective[127:32],
        effective[31:24],8'd5,8'd6,8'd1};
    c5_packet_tx sender(.clk(fab_clk),.rst_n(fab_rst_n),
        .in_valid(tx_request),.in_ready(tx_space),
        .in_payload(choose_response ? response_fab : meta_payload),
        .out_valid(control_valid),.out_ready(control_ready),
        .out_data(control_data),.out_k(control_k));
    assign response_fab_ack=sending && sending_response && saw_wire && !control_valid;
    assign meta_ready=sending && !sending_response && saw_wire && !control_valid;
    always @(posedge fab_clk or negedge fab_rst_n)
        if (!fab_rst_n) begin
            sending<=0; sending_response<=0; saw_wire<=0; response_seen<=0; effective<=0;
        end else begin
            if (!response_fab_valid) response_seen<=0;
            if (tx_request && tx_space) begin
                sending<=1; sending_response<=choose_response; saw_wire<=0;
                if (choose_response) begin effective<=response_fab; response_seen<=1; end
            end
            if (sending && control_valid) saw_wire<=1;
            if (sending && saw_wire && !control_valid) sending<=0;
        end
endmodule
