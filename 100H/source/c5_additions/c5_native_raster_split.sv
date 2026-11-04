// Native HDMI raster splitter. Every source pixel is retained; no scaling.
// META v2: mode 2=1280x480, mode 3=1280x960. Explicit frame state machine;
// a frame closes on its last good row, frame_done pulses then.
// Read-only counters/reason codes feed the descriptor page for diagnosis.
// fault_reason: 1 META rejected, 2 META superseded, 3 output FIFO full,
// 4 SOF before last row closed, 5 extra pixel, 6 bad row, 7 idle timeout.
module c5_native_raster_split #(parameter IDLE_LIMIT=62500000)(
    input wire clk,input wire rst_n,input wire axi_clk,input wire axi_rst_n,input wire enable,
    input wire deactivate,
    input wire meta_valid,input wire [159:0] meta_payload,input wire meta_ok,
    input wire vs_in,input wire hs_in,input wire de_in,input wire [15:0] pix_in,
    output reg fault,output reg active,
    output reg [15:0] half_width,output reg [15:0] height,output reg [1:0] mode,
    output reg [31:0] generation,output reg [31:0] frame_sequence,
    output reg frame_done,
    output reg [31:0] cnt_meta_ok,output reg [15:0] cnt_meta_bad,output reg [15:0] cnt_sof,
    output reg [31:0] cnt_eol,output reg [15:0] cnt_fault,output reg [3:0] fault_reason,
    output wire is_pending,output wire is_capturing,
    output wire vs5,output wire hs5,output wire de5,output wire [15:0] pix5,
    output wire vs6,output wire hs6,output wire de6,output wire [15:0] pix6
);
    localparam FMT_480=2,FMT_960=3;
    reg vs_q,hs_q,pending,capturing;
    reg [1:0] pending_mode;
    reg [31:0] pending_generation,pending_sequence;
    reg [12:0] x;
    reg [10:0] y;
    reg [15:0] active_width,active_height;
    reg [26:0] idle;
    assign is_pending=pending;assign is_capturing=capturing;
    wire [1:0] meta_mode=meta_payload[25:24];
    wire sof=vs_in && !vs_q;
    wire eol=hs_in && !hs_q;
    wire [12:0] expected_width=active_width;
    wire [10:0] expected_height=active_height[10:0];
    reg event_sof,event_eol,event_left,event_right;
    reg [15:0] event_pixel;
    // Per-frame state machine. META for frame N+1 normally arrives while frame
    // N is still open or just closed; it is queued as pending and opens at the
    // next SOF. A malformed or truncated frame reports fault for one cycle and
    // is dropped; the next META+SOF pair restarts cleanly (switch recovery).
    // deactivate (legacy META / receiver hold) leaves native mode entirely; so
    // does IDLE_LIMIT clocks without any native META/SOF/row (source gone).
    wire full5,full6;
    wire line_good=capturing && eol && !de_in && x==expected_width && y<expected_height && !vs_in;
    wire line_bad_now=capturing && eol && !de_in && !line_good;
    wire last_line=line_good && y==expected_height-1;
    wire pixel_bad=capturing && !sof && de_in && (x>=expected_width || y>=expected_height);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            vs_q<=0;hs_q<=0;pending<=0;capturing<=0;pending_mode<=0;
            pending_generation<=0;pending_sequence<=0;x<=0;y<=0;
            active_width<=0;active_height<=0;fault<=0;active<=0;half_width<=0;height<=0;mode<=0;
            generation<=0;frame_sequence<=0;frame_done<=0;
            event_sof<=0;event_eol<=0;event_left<=0;event_right<=0;event_pixel<=0;
            cnt_meta_ok<=0;cnt_meta_bad<=0;cnt_sof<=0;cnt_eol<=0;cnt_fault<=0;fault_reason<=0;idle<=0;
        end else begin
            vs_q<=vs_in;hs_q<=hs_in;frame_done<=0;fault<=0;
            event_sof<=0;event_eol<=0;event_left<=0;event_right<=0;
            if(!enable || deactivate)begin
                pending<=0;capturing<=0;active<=0;x<=0;y<=0;idle<=0;
            end else begin
                if(meta_valid || sof || eol)idle<=0;
                else if(active && idle!=IDLE_LIMIT)idle<=idle+1'b1;
                if(active && idle==IDLE_LIMIT)begin
                    active<=0;pending<=0;capturing<=0;x<=0;y<=0;
                    fault_reason<=4'd7;cnt_fault<=cnt_fault+1'b1;idle<=0;
                end
                if((event_sof || event_eol || event_left || event_right) && (full5 || full6))begin
                    fault<=1;capturing<=0;fault_reason<=4'd3;cnt_fault<=cnt_fault+1'b1;
                end
                if(meta_valid)begin
                    if(!meta_ok)begin
                        fault<=1;fault_reason<=4'd1;cnt_fault<=cnt_fault+1'b1;
                        cnt_meta_bad<=cnt_meta_bad+1'b1;
                    end else begin
                        cnt_meta_ok<=cnt_meta_ok+1'b1;
                        if(pending)begin fault<=1;fault_reason<=4'd2;cnt_fault<=cnt_fault+1'b1;end // newest wins
                        pending<=1;pending_mode<=meta_mode;
                        // Engage native mode (and publish geometry) before the
                        // SOF so the writer length and legacy masking are set.
                        active<=1;mode<=meta_mode;
                        half_width<=640;
                        height<=meta_mode==FMT_480?480:960;
                        pending_generation<=meta_payload[63:32];pending_sequence<=meta_payload[159:128];
                    end
                end
                if(sof)begin
                    if(capturing)begin fault<=1;fault_reason<=4'd4;cnt_fault<=cnt_fault+1'b1;end
                    capturing<=0;x<=0;y<=0;
                    if(pending)begin
                        capturing<=1;
                        active_width<=1280;
                        active_height<=pending_mode==FMT_480?480:960;
                        generation<=pending_generation;frame_sequence<=pending_sequence;
                        pending<=0;event_sof<=1;cnt_sof<=cnt_sof+1'b1;
                    end
                end else if(capturing)begin
                    if(de_in && x<expected_width && y<expected_height)begin
                        x<=x+1'b1;event_pixel<=pix_in;
                        if(x<{1'b0,half_width})event_left<=1;
                        else event_right<=1;
                    end
                    if(pixel_bad || line_bad_now)begin
                        fault<=1;capturing<=0;cnt_fault<=cnt_fault+1'b1;
                        fault_reason<=pixel_bad?4'd5:4'd6;
                    end else if(line_good)begin
                        x<=0;y<=y+1'b1;event_eol<=1;cnt_eol<=cnt_eol+1'b1;
                        if(last_line)begin frame_done<=1;capturing<=0;end
                    end
                end
            end
        end
    end
    // Same symbol layout as the established raster splitter: close, SOF, HS,
    // left-pixel, right-pixel, RGB565, sequence (unused in the native wrapper).
    wire [36:0] wr5={1'b0,event_sof,event_eol,event_left,event_right,event_pixel,16'd0};
    wire [36:0] wr6={1'b0,event_sof,event_eol,event_right,event_left,event_pixel,16'd0};
    wire empty5,empty6,valid5,valid6;
    wire [36:0] rd5,rd6;
    c5_native_output_fifo fifo5(.wr_clk(clk),.wr_rst_n(rst_n),.wr_valid(event_sof || event_eol || event_left),
        .wr_data(wr5),.full(full5),.rd_clk(axi_clk),.rd_rst_n(axi_rst_n),.rd_ready(1'b1),
        .rd_valid(valid5),.rd_data(rd5),.empty(empty5));
    c5_native_output_fifo fifo6(.wr_clk(clk),.wr_rst_n(rst_n),.wr_valid(event_sof || event_eol || event_right),
        .wr_data(wr6),.full(full6),.rd_clk(axi_clk),.rd_rst_n(axi_rst_n),.rd_ready(1'b1),
        .rd_valid(valid6),.rd_data(rd6),.empty(empty6));
    assign vs5=valid5 && rd5[35];assign hs5=valid5 && rd5[34];assign de5=valid5 && rd5[33];assign pix5=rd5[31:16];
    assign vs6=valid6 && rd6[35];assign hs6=valid6 && rd6[34];assign de6=valid6 && rd6[33];assign pix6=rd6[31:16];
endmodule
