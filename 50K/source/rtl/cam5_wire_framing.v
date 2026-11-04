`timescale 1ns/1ps
// Output HS is an EOL token, not a pixel quota guess at the receiver. DE gaps
// inside a row are permitted. VS closes the previous exact raster and opens
// the next only after that frame ID's FRAME_META has reached the wire.
module cam5_wire_framing(
    input clk,rst_n,enable,bypass,mode720,metadata_enable,
    input [18:0] in_video,output reg [18:0] out_video,
    output reg meta_valid,input meta_ready,output reg [31:0] frame_id,
    output reg fault
);
    reg vs_d,seen,pending_eol,waiting_meta,submitted,saw_busy,opened;
    reg [11:0] column;
    reg [9:0] rows;
    reg [2:0] vs_pulse;
    reg [31:0] next_id;
    wire [11:0] width=mode720 ? 12'd2560 : 12'd1280;
    wire [9:0] height=mode720 ? 10'd720 : 10'd480;
    wire sof=in_video[18] && !vs_d;
    always @(posedge clk or negedge rst_n)
        if(!rst_n)begin
            out_video<=0;meta_valid<=0;frame_id<=0;next_id<=1;fault<=0;
            vs_d<=0;seen<=0;pending_eol<=0;waiting_meta<=0;submitted<=0;
            saw_busy<=0;opened<=0;column<=0;rows<=0;vs_pulse<=0;
        end else begin
            out_video<=0;vs_d<=in_video[18];
            if(!enable)begin
                // frame IDs intentionally survive source/mode changes.
                meta_valid<=0;fault<=0;vs_d<=0;seen<=0;pending_eol<=0;
                waiting_meta<=0;submitted<=0;saw_busy<=0;opened<=0;
                column<=0;rows<=0;vs_pulse<=0;
                if(bypass)out_video<=in_video;
            end else if(!fault)begin
                if(meta_valid && meta_ready)begin meta_valid<=0;submitted<=1;end
                if(waiting_meta && submitted && !meta_ready)saw_busy<=1;
                if(waiting_meta && submitted && saw_busy && meta_ready)begin
                    waiting_meta<=0;opened<=1;vs_pulse<=4;
                end
                if(vs_pulse!=0)begin out_video[18]<=1;vs_pulse<=vs_pulse-1'b1;end
                if(sof)begin
                    if(seen && (rows!=height || column!=0 || pending_eol || waiting_meta))
                        fault<=1;
                    else begin
                        seen<=1;opened<=0;rows<=0;column<=0;
                        frame_id<=next_id;next_id<=next_id==32'hffffffff ? 1 : next_id+1'b1;
                        submitted<=0;saw_busy<=0;
                        if(metadata_enable)begin meta_valid<=1;waiting_meta<=1;end
                        else begin opened<=1;vs_pulse<=4;end
                    end
                end else if(in_video[16] && seen)begin
                    if(!opened || waiting_meta || vs_pulse!=0 || pending_eol || rows>=height)
                        fault<=1;
                    else begin
                        out_video<={2'b00,1'b1,in_video[15:0]};
                        if(column==width-1)begin column<=0;pending_eol<=1;end
                        else column<=column+1'b1;
                    end
                end else if(pending_eol)begin
                    out_video<={1'b0,1'b1,1'b0,16'd0};
                    pending_eol<=0;rows<=rows+1'b1;
                end
            end
        end
endmodule
