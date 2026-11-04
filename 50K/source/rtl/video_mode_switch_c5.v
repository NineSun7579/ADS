`timescale 1ns/1ps
// Donor video_mode_switch behavior, with a widened frame counter and held
// camera geometry. VGA/HDMI remain 614400 beats; C5 HD is 1843200 beats.
module video_mode_switch_c5 #(
    parameter TIMEOUT_CYCLES=6250000,DRAIN_CYCLES=32,FLUSH_CYCLES=8
)(
    input clk,rst_n,hdmi_request,cam_mode720,
    input [18:0] cam_video,hdmi_video,input hdmi_fault,
    output reg hdmi_active,
    output source_cam_request_n,source_hdmi_request_n,tx_request_n,
    output reg [18:0] video
);
    localparam RUN=0,DRAIN=1,FLUSH=2;
    (* ASYNC_REG="TRUE" *)reg [1:0]request_sync,fault_sync;
    reg [1:0]state;reg armed,in_frame;
    reg [20:0]pixels;reg [23:0]stalled;reg [7:0]delay_count;
    wire [18:0]selected=hdmi_active ? hdmi_video : cam_video;
    wire [20:0]frame_pixels=(!hdmi_active && cam_mode720) ? 21'd1843200 : 21'd614400;
    wire finish_pixel=armed && in_frame && selected[16] && pixels==frame_pixels-1;
    wire change_pending=request_sync[1]!=hdmi_active;
    wire empty_frame_boundary=selected[18] && !selected[16] && pixels==0;
    wire timeout=in_frame && (pixels!=0 || change_pending) && stalled==TIMEOUT_CYCLES-1;
    assign source_cam_request_n=rst_n && !hdmi_active && state!=FLUSH;
    assign source_hdmi_request_n=rst_n && hdmi_active && state!=FLUSH;
    assign tx_request_n=rst_n && state!=FLUSH;
    always @(posedge clk or negedge rst_n)
        if(!rst_n)begin
            request_sync<=0;fault_sync<=0;hdmi_active<=0;state<=FLUSH;
            delay_count<=0;armed<=0;in_frame<=0;pixels<=0;stalled<=0;video<=0;
        end else begin
            request_sync<={request_sync[0],hdmi_request};
            fault_sync<={fault_sync[0],hdmi_fault};video<=0;
            case(state)
            FLUSH:begin
                armed<=0;in_frame<=0;pixels<=0;stalled<=0;
                if(delay_count==FLUSH_CYCLES-1)begin delay_count<=0;state<=RUN;end
                else delay_count<=delay_count+1'b1;
            end
            DRAIN:begin
                if(delay_count==DRAIN_CYCLES-1)begin
                    hdmi_active<=request_sync[1];delay_count<=0;state<=FLUSH;
                end else delay_count<=delay_count+1'b1;
            end
            RUN:begin
                if(selected[18] && !selected[16])begin
                    armed<=1;in_frame<=1;pixels<=0;stalled<=0;
                    video<={selected[18:17],1'b0,16'b0};
                end else if(armed && in_frame)begin
                    video<=selected;
                    if(selected[16])begin
                        pixels<=pixels+1'b1;stalled<=0;
                        if(finish_pixel)in_frame<=0;
                    end else if(stalled<TIMEOUT_CYCLES-1)stalled<=stalled+1'b1;
                end
                if((change_pending && (!in_frame || finish_pixel || empty_frame_boundary)) || timeout ||
                    (hdmi_active && fault_sync[1]))begin
                    state<=DRAIN;delay_count<=0;armed<=0;in_frame<=0;
                    if(!finish_pixel)video<=0;
                end
            end
            default:state<=FLUSH;
            endcase
        end
endmodule
