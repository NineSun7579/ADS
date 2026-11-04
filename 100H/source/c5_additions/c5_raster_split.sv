// Version-1 metadata negotiates strict HS-per-row framing. Legacy epoch zero
// remains display compatible but NEVER contributes verified raster evidence.
module c5_raster_split_pipe #(parameter FIFO_D=1024)(
 input wire rx_clk,rx_rst_n,hold,input wire hd_in,run_in,settle_in,
 input wire [31:0] epoch_in,
 input wire meta_valid_in,input wire [159:0] meta_payload_in,
 input wire vs_in,hs_in,de_in,input wire [15:0] pix_in,
 output wire input_pending,
 output reg fault,output reg [31:0] rx_verified_frontier,
 input wire axi_clk,axi_rst_n,
 output reg vs5,hs5,de5,output reg [15:0] pix5,
 output reg vs6,hs6,de6,output reg [15:0] pix6,
 output reg [31:0] frame_sequence,
 output reg raster_done,output reg [31:0] raster_sequence
);
 // One complete ordered transaction per clock. No ready/no selective delay:
 // static header predicates, full payload and video/context have identical age.
 reg input_valid,meta_valid,vs,hs,de,hd,run_q;
 reg [31:0] epoch;
 reg [159:0] meta_payload;
 reg [15:0] pix;
 (* syn_preserve=1 *) reg header_kind_ok,header_geometry_ok,identity_nonzero;
 wire run=run_q && run_in;
 wire reset_rx_n=rx_rst_n && !hold;
 always @(posedge rx_clk or negedge reset_rx_n)begin
  if(!reset_rx_n)begin
   input_valid<=0;meta_valid<=0;vs<=0;hs<=0;de<=0;hd<=0;run_q<=0;epoch<=0;meta_payload<=0;pix<=0;
   header_kind_ok<=0;header_geometry_ok<=0;identity_nonzero<=0;
  end else begin
   input_valid<=1;meta_valid<=meta_valid_in;vs<=vs_in;hs<=hs_in;de<=de_in;
   hd<=hd_in;run_q<=run_in;epoch<=epoch_in;meta_payload<=meta_payload_in;pix<=pix_in;
   header_kind_ok<=meta_payload_in[7:0]==1 && meta_payload_in[15:8]==6 && meta_payload_in[23:16]==5;
   header_geometry_ok<=meta_payload_in[31:24]=={7'd0,hd_in} &&
    meta_payload_in[79:64]==(hd_in?16'd1280:16'd640) && meta_payload_in[95:80]==(hd_in?16'd720:16'd480) &&
    meta_payload_in[111:96]==16'd640 && meta_payload_in[127:112]==16'd480;
   identity_nonzero<=meta_payload_in[159:128]!=0;
  end
 end
 reg vq,hq,open,pending;
 // A corrupted row abandons its frame: pixels are refused until the next
 // VS, so one bad packet costs one frame instead of a terminal fault.
 reg drop;
 reg [12:0] x;reg [9:0] y;
 reg [31:0] seq,pending_sequence;
 wire strict=(epoch!=0);
 wire sof=vs && !vq;
 wire eol=hs && !hq;
 wire [12:0] width=hd?13'd2560:13'd1280;
 wire [12:0] split=hd?13'd1280:13'd640;
 wire [9:0] height=hd?10'd720:10'd480;
 wire complete=(y==height && x==0);
 // Dynamic checks use CURRENT consumed state, never an old predecode seq.
 wire context_ok=(epoch==epoch_in && hd==hd_in);
 // Previous-epoch pixels/META still in flight after ARM are stale, not corrupt.
 // They are still refused (context_ok gates every write), but must not latch a
 // terminal raster fault while the negotiated switch is settling.
 wire stale_input=settle_in && !context_ok;
 wire meta_ok=header_kind_ok && header_geometry_ok && identity_nonzero &&
  meta_payload[63:32]==epoch_in && context_ok && meta_payload[159:128]>seq;
  // While settling, a truncated frame must not block the next one: accepting the
  // new META is what resynchronises x/y/open. Outside the window this keeps its
  // original fail-closed meaning.
  wire meta_bad=input_valid && meta_valid && (!strict || !meta_ok || pending ||
   ((open && !complete) && !settle_in));
  // Existing same-cycle acceptance transaction, named on the actual shared
  // pending flag/sequence CE so ADS may replicate its local distribution.
  // No extra stage: pending identity and validity still capture atomically.
  wire pending_capture_en /* synthesis syn_keep=1 syn_maxfan=16 */;
  assign pending_capture_en=input_valid && meta_valid && !meta_bad;
 wire close_bad=strict && sof && open && (!complete || de || hs);
 wire line_bad=strict && run && ((eol && (!open || x!=width || y>=height || de || vs)) ||
  (de && (!open || hs || vs || x>=width || y>=height)));
 wire take_sof=input_valid && sof && run && !fault && !close_bad && context_ok && (!strict || pending);
 wire take_pixel=input_valid && de && open && !fault && !drop && run && !line_bad && !sof && context_ok;
 wire native6=(x>=split && x<split+13'd640 && y<10'd480);
 wire pad_bad=strict && take_pixel && x>=split && !native6 && pix!=0;
 wire close_good=input_valid && sof && open && strict && complete && run && !fault && !close_bad && context_ok;
 // One symbol can close the preceding frame and open the following one.
 // Preserve BOTH sender identities, rather than reusing a locally made counter.
 wire [84:0] sym={close_good,take_sof,hs,take_pixel && x<split,
  take_pixel && native6,pix,(strict?pending_sequence:32'd0),seq};
 wire empty,full;wire [84:0] head;
 wire wr=(take_sof || take_pixel || close_good) && !pad_bad && !meta_bad;
 reg accepted_valid;reg [84:0] accepted_symbol;
 // Input stage and accepted-symbol register are two distinct owned storage
 // slots before BRAM. Both remain visible to ordered health draining; full
 // rejects a pending write with sticky fault rather than overwriting storage.
 assign input_pending=input_valid && (meta_valid || de || vs!=vq || hs!=hq) || accepted_valid;
 // Comparator/fault logic ends at this register, never at BRAM write-enable.
 // Both token and valid advance together. A reserved pending slot is explicit;
 // full with a pending symbol is sticky overflow, never silent storage loss.
 always @(posedge rx_clk or negedge reset_rx_n)begin
  if(!reset_rx_n)begin accepted_valid<=0;accepted_symbol<=0;end
  else begin accepted_valid<=wr;accepted_symbol<=sym;end
 end
 always @(posedge rx_clk or negedge reset_rx_n) begin
   if(!reset_rx_n) begin vq<=0;hq<=0;open<=0;pending<=0;drop<=0;x<=0;y<=0;seq<=0;pending_sequence<=0;fault<=0;rx_verified_frontier<=0;end
  else begin
   vq<=vs;hq<=hs;
   if(close_good && !meta_bad && !line_bad && !pad_bad && !(accepted_valid && full))rx_verified_frontier<=seq;
    if(input_valid && meta_valid) begin
     if(meta_bad && !settle_in) fault<=1;
    end
    if(pending_capture_en)begin pending<=1;pending_sequence<=meta_payload[159:128];end
   if(sof) begin
    drop<=0;
    if(close_bad && !settle_in) fault<=1;
    open<=take_sof;x<=0;y<=0;
    if(take_sof && strict) begin seq<=pending_sequence;pending<=0;end
   end else if(strict) begin
    if(take_pixel) x<=x+1'b1;
    if(eol && open && !line_bad) begin x<=0;y<=y+1'b1;end
   end else if(take_pixel) begin
    // Only pre-negotiation legacy video uses quota-based row wrapping.
    if(x==width-1) begin x<=0;y<=y+1'b1;end else x<=x+1'b1;
   end
    // During a negotiated switch the previous mode's pixels are still in flight.
    // They are already refused (line/context checks gate every write) and must
    // not latch a terminal raster fault until the new mode produces a frame.
    // A corrupt row abandons this frame instead of latching a terminal fault;
    // abandoning (open<=0) also makes the untouched close_bad/meta_bad
    // predicates false for it, so the next META opens a clean frame.
    // The settle window may forgive a terminal fault, never certify a damaged
    // frame. Refused extra pixels/nonzero padding must abandon the frame in
    // either mode; the next valid META/VS still resynchronises without fault.
    if(line_bad || pad_bad) begin
     drop<=1;open<=0;x<=0;y<=0;
    end
    // Context mismatch and real storage overflow stay terminal.
    if((!settle_in && (!stale_input && input_valid &&
      (meta_valid || de || sof || eol) && !context_ok))
      || (accepted_valid && full)) fault<=1;
  end
 end
 c5_bram_async_fifo #(.WIDTH(85),.DEPTH(FIFO_D)) fifo(
  .wr_clk(rx_clk),.wr_rst_n(reset_rx_n),.wr_en(accepted_valid),.wr_data(accepted_symbol),.full(full),
  .rd_clk(axi_clk),.rd_rst_n(axi_rst_n),.rd_en(!empty),.rd_data(head),.empty(empty));
 always @(posedge axi_clk or negedge axi_rst_n) begin
  if(!axi_rst_n) begin vs5<=0;hs5<=0;de5<=0;pix5<=0;vs6<=0;hs6<=0;de6<=0;pix6<=0;frame_sequence<=0;raster_done<=0;raster_sequence<=0;end
  else begin
   vs5<=0;vs6<=0;de5<=0;de6<=0;raster_done<=0;
   if(!empty) begin
    vs5<=head[83];vs6<=head[83];hs5<=head[82];hs6<=head[82];
    de5<=head[81];de6<=head[80];pix5<=head[79:64];pix6<=head[79:64];
    if(head[83]) frame_sequence<=head[63:32];
    raster_done<=head[84];if(head[84]) raster_sequence<=head[31:0];
   end
  end
 end
endmodule
