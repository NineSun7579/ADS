`timescale 1ns/1ps
// ABI v1 local command sequencer. Packet validation and CDC precede this
// module. SET prepares while held; COMMIT releases only after RUNNING has
// been handed to the response sender. Duplicate epochs never reconfigure.
module cam5_mode_control #(parameter TIMEOUT_CYCLES=250000000)(
    input clk, rst_n, input command_valid, output command_ready,
    input [7:0] command_type, input command_mode720,
    input [31:0] command_epoch,
    output reg mode720, output reg [31:0] epoch,
    output reg capture_hold, output reg config_start,
    input config_done, config_error, input [15:0] actual_width, actual_height,
    input transport_fault, input [3:0] fault_detail,
    output reg ready, output reg failed,
    output reg response_valid, input response_ready,
    output reg [7:0] response_type, output reg [31:0] response_detail
);
    localparam IDLE=0, HOLD=1, CONFIG=2, PREPARED=3, ANNOUNCE=4,
               RUNNING=5, FAILED=6;
    reg [2:0] state;
    reg [31:0] timeout_count;
    reg have_epoch,boot_pending;
    assign command_ready=!response_valid && state!=ANNOUNCE;
    task reply;
        input [7:0] kind; input [31:0] detail;
        begin response_valid<=1; response_type<=kind; response_detail<=detail; end
    endtask
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            state<=IDLE; mode720<=0; epoch<=0; capture_hold<=1;
            config_start<=0; ready<=0; failed<=0; response_valid<=0;
            response_type<=0; response_detail<=0; timeout_count<=0; have_epoch<=0;boot_pending<=1;
        end else begin
            config_start<=0;
            if(boot_pending) begin boot_pending<=0;state<=HOLD;end
            if (response_valid && response_ready) begin
                response_valid<=0;
                if (state==ANNOUNCE) begin capture_hold<=0; state<=RUNNING; end
            end
            if (state==HOLD) begin config_start<=1; timeout_count<=0; state<=CONFIG; end
            if (state==CONFIG) begin
                timeout_count<=timeout_count+1;
                if ((timeout_count>2 && config_error) || timeout_count==TIMEOUT_CYCLES-1) begin
                    failed<=1; state<=FAILED; reply(5,config_error ? 32'd1 : 32'd2);
                end else if (timeout_count>2 && config_done) begin
                    if (actual_width==(mode720 ? 1280 : 640) &&
                        actual_height==(mode720 ? 720 : 480)) begin
                        ready<=1;
                        if(!have_epoch) begin state<=RUNNING;capture_hold<=0;end
                        else begin state<=PREPARED;reply(2,0);end
                    end else begin failed<=1; state<=FAILED; reply(5,3); end
                end
            end
            if (command_valid && command_ready) begin
                if (command_type==1) begin
                    if (have_epoch && command_epoch==epoch) begin
                        if (command_mode720!=mode720) reply(5,4);
                        else if (state==PREPARED) reply(2,0);
                        else if (state==RUNNING) reply(4,0);
                        else if (state==FAILED) reply(5,response_detail);
                        // Duplicate SET while configuring waits for original READY.
                    end else if(have_epoch && command_epoch<epoch)begin
                        // Parent mailbox requires increasing epochs (wd>epoch).
                        // A delayed retry from an older epoch cannot roll back
                        // sensor mode or restart configuration.
                    end else if (state==CONFIG || state==HOLD) begin
                        // Busy request cannot replace the held epoch. No reply
                        // with the wrong epoch; originating controller times out.
                    end else if (command_epoch!=0) begin
                        mode720<=command_mode720; epoch<=command_epoch; have_epoch<=1;
                        capture_hold<=1; ready<=0; failed<=0; state<=HOLD;
                    end
                end else if (command_type==3 && have_epoch &&
                             command_epoch==epoch && command_mode720==mode720) begin
                    if (state==PREPARED) begin reply(4,0); state<=ANNOUNCE; end
                    else if (state==RUNNING) reply(4,0);
                    else if (state==FAILED) reply(5,response_detail);
                end
            end
            if (transport_fault && state==RUNNING) begin
                capture_hold<=1; ready<=0; failed<=1; state<=FAILED;
        reply(5,32'h500|{28'd0,fault_detail});
            end
        end
endmodule
