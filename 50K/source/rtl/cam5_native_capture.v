// Native HDMI capture. Exact 1280x480 or 1280x960 input/output, no scaling.
// The mode is decided by the measured frame height (width is always 1280).
// A complete measurement frame qualifies the following frame. META is sent
// over a one-outstanding bundle CDC; the read side holds the marked SOF of
// that frame until meta_sent reports the META packet is on the wire, so the
// receiver always sees META before SOF. Each row ends with an HS token.
// generation survives request_n resets and advances only on a mode change.
module cam5_native_capture(
    input wire pclk,input wire out_clk,input wire por_n,input wire request_n,input wire capture_ready,
    input wire meta_sent,
    input wire vs_pin,input wire hs_pin,input wire de_pin,
    input wire [7:0] r_pin,input wire [7:0] g_pin,input wire [7:0] b_pin,
    output reg [18:0] video,output reg fault,output reg format_ok,
    output wire meta_valid,input wire meta_ready,output wire [159:0] meta_payload,
    output wire [1:0] geometry_mode,output wire [31:0] generation,
    // Diagnostics (read-only): toggles flip once per event, levels are raw.
    output wire [3:0] dbg_p_tog,output wire [2:0] dbg_p_lvl,output wire [3:0] dbg_o_tog,
    output wire [12:0] dbg_v0,output wire [12:0] dbg_v1,output wire [12:0] dbg_v2,output wire [12:0] dbg_v3,
    output wire [5:0] dbg_flags
);
    // MS7200 launches on the rising pclk edge; data settles within 4 ns. The
    // falling-edge IOB register samples it half a period later; with the
    // global-tree insertion delay (2.5..5.7 ns over corners) that point stays
    // inside the stable window for pixel clocks up to 74.25 MHz (30 fps
    // 1280x960 / 1280x480), which is what pixclk_in is constrained to.
    // A plain register follows the IOB stage before any logic.
    (* syn_useioff=1 *) reg vs_io,hs_io,de_io;
    (* syn_useioff=1 *) reg [7:0] r_io,g_io,b_io;
    always @(negedge pclk) {vs_io,hs_io,de_io,r_io,g_io,b_io}<={vs_pin,hs_pin,de_pin,r_pin,g_pin,b_pin};
    reg vs_in,hs_in,de_in;
    reg [7:0] r_in,g_in,b_in;
    always @(posedge pclk) {vs_in,hs_in,de_in,r_in,g_in,b_in}<={vs_io,hs_io,de_io,r_io,g_io,b_io};
    // request_n comes from another clock domain: assert asynchronously,
    // release locally in each domain (video_reset_sync), never use it raw.
    wire pclk_rst_n,out_rst_n;
    video_reset_sync u_pclk_reset(pclk,request_n,pclk_rst_n);
    video_reset_sync u_out_reset(out_clk,request_n,out_rst_n);
    reg vs_d,de_d,admit,measure_bad,output_bad;
    reg [12:0] x,lines,output_x,output_lines;
    reg measured_known;
    reg [1:0] measured_mode,active_mode;
    reg [12:0] measured_width,measured_height;
    reg [31:0] frame_id,next_generation;
    reg [1:0] generation_mode;
    reg [159:0] meta_source;
    reg meta_source_valid;
    reg [18:0] event_data;
    reg event_en;
    reg event_sof;
    reg pending_valid;
    reg [18:0] pending_data;
    wire serialized_en=pending_valid || event_en;
    wire [18:0] serialized_data=pending_valid?pending_data:event_data;
    wire serializer_overflow=pending_valid && event_en && event_sof;
    wire full,empty,pop;wire [18:0] head;
    wire vs_start=vs_in && !vs_d,line_end=!de_in && de_d;
    // The final active row may end on the same sample as the VS rising edge.
    // Include that row when qualifying the completed frame; the VS branch has
    // priority over the ordinary DE/line accounting below.
    wire final_line=vs_start && line_end && !vs_d;
    wire [12:0] completed_lines=lines+(final_line?1'b1:1'b0);
    wire [1:0] frame_mode=completed_lines==480?2'd2:2'd3;
    wire frame_ok=measured_known && !measure_bad && (completed_lines==480 || completed_lines==960) &&
        (!final_line || x==measured_width);
    wire [12:0] active_width=1280;
    wire [12:0] active_height=active_mode==2?480:960;
    wire crop_pixel=de_in && !vs_in && admit && output_x<active_width && output_lines<active_height;
    reg [1:0] ready_sync;
    always @(posedge pclk or negedge pclk_rst_n)
        if(!pclk_rst_n)ready_sync<=0;else ready_sync<={ready_sync[0],capture_ready};
    wire meta_source_ready;
    always @(posedge pclk or negedge pclk_rst_n) begin
        if(!pclk_rst_n)begin
            vs_d<=0;de_d<=0;admit<=0;measure_bad<=0;output_bad<=0;
            x<=0;lines<=0;output_x<=0;output_lines<=0;measured_known<=0;
            measured_mode<=0;measured_width<=0;measured_height<=0;active_mode<=0;
            frame_id<=0;meta_source<=0;meta_source_valid<=0;
            event_en<=0;event_data<=0;event_sof<=0;fault<=0;format_ok<=0;
        end else begin
            if(meta_source_valid && meta_source_ready)meta_source_valid<=0;
            vs_d<=vs_in;de_d<=de_in;event_en<=0;event_sof<=0;
            if((serialized_en && full) || serializer_overflow)begin fault<=1;admit<=0;format_ok<=0;end
            else if(!ready_sync[1])begin
                admit<=0;format_ok<=0;measure_bad<=0;output_bad<=0;
                x<=0;lines<=0;output_x<=0;output_lines<=0;
                measured_known<=0;meta_source_valid<=0;
            end else if(vs_start)begin
                // The completed measurement frame determines admission of the next.
                format_ok<=frame_ok && !fault;
                admit<=frame_ok && !fault && meta_source_ready;
                output_x<=0;output_lines<=0;
                if(frame_ok)begin
                    active_mode<=frame_mode;
                    if(meta_source_ready)begin
                        frame_id<=frame_id+1'b1;
                        meta_source_valid<=1;
                        meta_source<=0;
                        meta_source[7:0]<=2;meta_source[15:8]<=6;meta_source[23:16]<=5;
                        meta_source[25:24]<=frame_mode;
                        meta_source[63:32]<=frame_mode==generation_mode?next_generation:next_generation+1'b1;
                        meta_source[79:64]<=measured_width;
                        meta_source[95:80]<=completed_lines;
                        meta_source[159:128]<=frame_id+1'b1;
                    end
                end
                if(admit && ((!final_line && (output_x!=0 || output_lines!=active_height)) ||
                    (final_line && (output_x!=active_width || output_lines+1'b1!=active_height)) || output_bad))begin
                    fault<=1;admit<=0;format_ok<=0;
                end
                // Close the final row before the next marked SOF when its DE
                // falling edge coincides with VS. This preserves every HS token.
                if(admit && final_line)begin
                    event_en<=!fault;event_data<={1'b0,1'b1,1'b0,16'b0};
                    event_sof<=frame_ok && !fault && meta_source_ready;
                end else begin
                    event_en<=frame_ok && !fault && meta_source_ready;
                    event_data<={1'b1,1'b0,1'b0,16'h0001}; // marked: META precedes it
                end
                measure_bad<=0;output_bad<=0;measured_known<=0;
                measured_height<=0;x<=0;lines<=0;
            end else if(!vs_in)begin
                if(de_in)begin
                    if(x<8191)x<=x+1'b1;
                    if(admit)begin
                        if(output_x<8191)output_x<=output_x+1'b1;
                        if(output_x>=active_width || output_lines>=active_height)begin
                            output_bad<=1;fault<=1;admit<=0;format_ok<=0;end
                    end
                    if(x>=1280 || lines>=960)begin measure_bad<=1;admit<=0;format_ok<=0;end
                end
                if(line_end)begin
                    measured_height<=lines+1'b1;
                    if(admit)begin
                        output_x<=0;
                        if(output_x!=active_width || output_lines>=active_height)begin
                            output_bad<=1;fault<=1;admit<=0;format_ok<=0;end
                        else if(output_lines<8191)output_lines<=output_lines+1'b1;
                    end
                    x<=0;if(lines<8191)lines<=lines+1'b1;
                    if(!measured_known)begin
                        measured_known<=x==1280;
                        measured_mode<=0;measured_width<=x;measured_height<=lines+1'b1;
                        if(x!=1280)measure_bad<=1;
                    end else if(x!=measured_width)begin
                        measure_bad<=1;
                        // Measurement mismatch never truncates an admitted frame;
                        // active output checks above use active_width instead.
                    end
                end
                // A pixel word also clears the VS level, so it wins over the
                // VS-release token when a row starts right after VS.
                if(crop_pixel && !fault)begin
                    event_en<=1;event_data<={1'b0,1'b0,1'b1,r_in[7:3],g_in[7:2],b_in[7:3]};
                end else if(vs_d)begin
                    if(admit)begin event_en<=!fault;event_data<=0;end
                end else if(line_end)begin
                    if(admit)begin event_en<=!fault;event_data<={1'b0,1'b1,1'b0,16'b0};end
                end
            end
        end
    end
    // A coincident final HS / SOF needs two FIFO writes. Carry the SOF in
    // this one-word skid slot; if a pixel follows immediately, replace the
    // drained SOF with that pixel rather than suppressing input accounting.
    // Subsequent events retain their order until an event-free blank drains
    // the slot. At least one such cycle is needed before the next collision;
    // a permanently saturated stream cannot transport two tokens per clock.
    always @(posedge pclk or negedge pclk_rst_n) begin
        if(!pclk_rst_n)begin pending_valid<=0;pending_data<=0;end
        else if(!ready_sync[1] || fault || (serialized_en && full) || serializer_overflow)
            pending_valid<=0;
        else if(pending_valid)begin
            pending_valid<=event_en;
            if(event_en)pending_data<=event_data;
        end else if(event_en && event_sof)begin
            pending_valid<=1;pending_data<={1'b1,1'b0,1'b0,16'h0001};
        end
    end
    wire generation_step=pclk_rst_n && ready_sync[1] && vs_start && frame_ok && !fault &&
        meta_source_ready && !(serialized_en && full) && !serializer_overflow;
    always @(posedge pclk or negedge por_n)
        if(!por_n)begin next_generation<=0;generation_mode<=0;end
        else if(generation_step && frame_mode!=generation_mode)begin
            next_generation<=next_generation+1'b1;generation_mode<=frame_mode;
        end
    // Block-RAM FIFO (FWFT head, stable under backpressure). The banked
    // LUT-RAM FIFO of the legacy path cost ~1.2k distributed-RAM sites at this
    // depth and congested the 50K router. Common async assertion, release
    // synchronized locally in each domain, as the FIFO requires.
    wire fifo_wr_rst_n=pclk_rst_n,fifo_rd_rst_n=out_rst_n;
    cam5_bram_async_fifo #(.WIDTH(19),.DEPTH(4096)) fifo(
        .wr_clk(pclk),.wr_rst_n(fifo_wr_rst_n),.wr_en(serialized_en && !fault),.wr_data(serialized_data),.full(full),
        .rd_clk(out_clk),.rd_rst_n(fifo_rd_rst_n),.rd_en(pop),.rd_data(head),.empty(empty));
    // One credit per META packet on the wire; one marked SOF consumes it.
    reg meta_credit;
    wire head_meta_sof=!empty && head[18] && !head[16] && head[0];
    assign pop=!empty && (!head_meta_sof || meta_credit);
    always @(posedge out_clk or negedge out_rst_n)
        if(!out_rst_n)meta_credit<=0;
        else if(pop && head_meta_sof)meta_credit<=0;
        else if(meta_sent)meta_credit<=1;
    always @(posedge out_clk or negedge out_rst_n)
        if(!out_rst_n)video<=0;
        else if(pop)video<={head[18:16],head[15:1],head[0] && head[16]};
        else video<={video[18:17],1'b0,16'b0};
    cam5_bundle_cdc #(.WIDTH(160)) meta_cdc(
        .s_clk(pclk),.s_rst_n(pclk_rst_n),.s_data(meta_source),.s_valid(meta_source_valid),
        .s_ready(meta_source_ready),.d_clk(out_clk),.d_rst_n(out_rst_n),
        .d_data(meta_payload),.d_valid(meta_valid),.d_ready(meta_ready));
    // ---- diagnostics: vs, row end, qualified frame, META queued (pclk) ----
    reg tg_vs=1'b0,tg_line=1'b0,tg_fok=1'b0,tg_mq=1'b0,msv_d=1'b0;
    always @(posedge pclk) begin
        msv_d<=meta_source_valid;
        if(vs_start)tg_vs<=~tg_vs;
        if(line_end)tg_line<=~tg_line;
        if(vs_start && frame_ok && ready_sync[1])tg_fok<=~tg_fok;
        if(meta_source_valid && !msv_d)tg_mq<=~tg_mq;
    end
    // ---- diagnostics: raw measurement of the incoming raster (independent of
    // the capture state machine; values latch at each VS rising edge) ----
    reg [12:0] m_x=13'd0,m_rows=13'd0,m_first=13'd0,m_max=13'd0,m_min=13'h1fff;
    reg m_known=1'b0,m_vs_d=1'b0,m_de_d=1'b0;
    reg [12:0] l_first=13'd0,l_rows=13'd0,l_max=13'd0,l_min=13'd0;
    // verdicts on the last complete frame: {narrow,wide,rows480,rows960,equal,first1280}
    reg [5:0] l_flags=6'd0;
    wire m_vs_start=vs_in && !m_vs_d;
    wire m_row_end=!de_in && m_de_d;
    wire [12:0] m_rows_final=m_rows+((m_vs_start && m_row_end) ? 13'd1 : 13'd0);
    wire [12:0] m_final_first=(!m_known && m_row_end)?m_x:m_first;
    wire [12:0] m_final_max=(m_row_end && m_x>m_max)?m_x:m_max;
    wire [12:0] m_final_min=(m_row_end && m_x<m_min)?m_x:m_min;
    always @(posedge pclk) begin
        m_vs_d<=vs_in;m_de_d<=de_in;
        if(m_vs_start)begin
            l_first<=m_final_first;l_rows<=m_rows_final;l_max<=m_final_max;l_min<=(m_final_min==13'h1fff)?13'd0:m_final_min;
            l_flags<={(m_final_min!=13'h1fff && m_final_min<13'd1280),(m_final_max>13'd1280),(m_rows_final==13'd480),
                      (m_rows_final==13'd960),(m_final_max==m_final_min && m_final_max!=13'd0),(m_final_first==13'd1280)};
            m_rows<=13'd0;m_x<=13'd0;m_max<=13'd0;m_min<=13'h1fff;m_known<=1'b0;
        end else if(!vs_in)begin
            if(de_in && m_x!=13'h1fff)m_x<=m_x+1'b1;
            if(m_row_end)begin
                if(m_rows!=13'h1fff)m_rows<=m_rows+1'b1;
                m_x<=13'd0;
                if(m_x>m_max)m_max<=m_x;
                if(m_x<m_min)m_min<=m_x;
                if(!m_known)begin m_first<=m_x;m_known<=1'b1;end
            end
        end
    end
    assign dbg_v0=l_first;assign dbg_v1=l_rows;assign dbg_v2=l_max;assign dbg_v3=l_min;
    assign dbg_flags=l_flags;
    assign dbg_p_tog={tg_mq,tg_fok,tg_line,tg_vs};
    assign dbg_p_lvl={admit,fault,measure_bad};
    // ---- diagnostics: META on wire, marked SOF released, pixel slice (out_clk) ----
    reg tg_ms=1'b0,tg_sof=1'b0;reg [16:0] pixcnt=17'd0;
    always @(posedge out_clk) begin
        if(meta_sent)tg_ms<=~tg_ms;
        if(pop && head_meta_sof)tg_sof<=~tg_sof;
        if(pop && head[16])pixcnt<=pixcnt+1'b1;
    end
    assign dbg_o_tog={1'b0,pixcnt[16],tg_sof,tg_ms};
    assign geometry_mode=meta_payload[25:24];
    assign generation=meta_payload[63:32];
endmodule
