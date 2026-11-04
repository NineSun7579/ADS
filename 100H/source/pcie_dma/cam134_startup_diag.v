// Isolated read-only startup observation. No functional control outputs.
module cam134_startup_diag # (parameter ADDR_WIDTH=12) (
 input pclk, input prst, input free_clk, input root_rst,
 input axi_clk, input axi_rst, input ddr_init,
 input [5:0] ddr_locks, input [127:0] ddr_debug,
 input rd_en, input [ADDR_WIDTH-1:0] rd_addr, output reg [127:0] rd_data,
 input cmd_accept, input [31:0] cmd_value,
 input [31:0] desc_addr, input [31:0] desc_length,
 input busy_start, input running, input dequeue, input fifo_empty,
 input [9:0] fifo_level, input msi_req, input msi_grant,
 input start_axi, input [1:0] phase, input read_started,
 input [31:0] remain, input [31:0] araddr, input [3:0] arlen,
 input arvalid, input arready, input rvalid, input rready,
 input [3:0] rid, input rlast, input [1:0] rresp,
 input [31:0] rdata_low, input enqueue, input fifo_full
);
 reg [31:0] pbeat, cmds, last_cmd, last_desc, last_length;
 reg [31:0] starts_p, dequeues, msis, grants;
 reg msi_d;
 reg req, free_req;
 reg [7:0] poll;
 reg [1:0] free_ack_sync, axi_ack_sync;
 reg [255:0] free_view;
 reg [511:0] axi_view;
 reg free_valid, axi_valid, free_gen, axi_gen;
 reg [31:0] free_age, axi_age;
 reg [1:0] init_sync, reset_sync;
 // First stages alone receive asynchronous control levels/toggles.
 reg [1:0] free_req_sync, axi_req_sync;
 reg free_ack, axi_ack;
 reg [255:0] free_hold;
 reg [511:0] axi_hold;
 reg [31:0] fbeat, dbeat;
 reg [5:0] locks_s1, locks_s2;
 reg [127:0] sample_debug;
 reg [1:0] dclock_sync, finit_sync, frst_sync;
 reg dclock_d, finit_d, frst_d;
 reg [31:0] clock_edges;
 reg [3:0] sticky;
 reg [31:0] astarts, ars, rs, lasts, enqueues;
 reg [31:0] last_ar, last_r;
 reg [31:0] last_meta;
 // One native-clock observation stage: raw fabric nets drive only these flops.
 // Events, payloads and live status all use the same delayed sample.
 reg sample_reset, sample_start, sample_ar, sample_r, sample_enqueue;
 reg [31:0] sample_addr, sample_remain, sample_data, sample_beat;
 reg [3:0] sample_len, sample_id;
 reg [1:0] sample_resp, sample_phase;
 reg sample_last, sample_full, sample_rready, sample_rvalid;
 reg sample_arready, sample_arvalid, sample_started;
 always @(posedge axi_clk or posedge root_rst) begin
  if(root_rst) begin
   sample_debug<=0; sample_reset<=1; sample_start<=0; sample_ar<=0; sample_r<=0; sample_enqueue<=0;
   sample_addr<=0; sample_remain<=0; sample_data<=0; sample_beat<=0;
   sample_len<=0; sample_id<=0; sample_resp<=0; sample_phase<=0;
   sample_last<=0; sample_full<=0; sample_rready<=0; sample_rvalid<=0;
   sample_arready<=0; sample_arvalid<=0; sample_started<=0;
  end else begin
   sample_debug<=ddr_debug; sample_reset<=axi_rst; sample_start<=start_axi;
   sample_ar<=arvalid && arready; sample_r<=rvalid && rready && rid==0;
   sample_enqueue<=enqueue && !fifo_full;
   sample_addr<=araddr; sample_remain<=remain; sample_data<=rdata_low; sample_beat<=dbeat;
   sample_len<=arlen; sample_id<=rid; sample_resp<=rresp; sample_phase<=phase;
   sample_last<=rlast; sample_full<=fifo_full; sample_rready<=rready; sample_rvalid<=rvalid;
   sample_arready<=arready; sample_arvalid<=arvalid; sample_started<=read_started;
  end
 end
 // DDR activity counter is reset only by board root reset, never DDR init.
 always @(posedge axi_clk or posedge root_rst)
  if(root_rst) dbeat<=0; else dbeat<=dbeat+1'b1;
 always @(posedge free_clk or posedge root_rst) begin
  if(root_rst) begin
   locks_s1<=0; locks_s2<=0; fbeat<=0; free_req_sync<=0; free_ack<=0; free_hold<=0;
   dclock_sync<=0; finit_sync<=0; frst_sync<=0;
   dclock_d<=0; finit_d<=0; frst_d<=0; clock_edges<=0; sticky<=0;
  end else begin
   locks_s1<=ddr_locks; locks_s2<=locks_s1; fbeat<=fbeat+1'b1;
   free_req_sync<={free_req_sync[0],free_req};
   dclock_sync<={dclock_sync[0],dbeat[8]};
   finit_sync<={finit_sync[0],ddr_init};
   frst_sync<={frst_sync[0],axi_rst};
   dclock_d<=dclock_sync[1]; finit_d<=finit_sync[1]; frst_d<=frst_sync[1];
   if(dclock_d!=dclock_sync[1]) clock_edges<=clock_edges+1'b1;
   if(!finit_d && finit_sync[1]) sticky[0]<=1;
   if(finit_d && !finit_sync[1]) sticky[1]<=1;
   if(!frst_d && frst_sync[1]) sticky[2]<=1;
   if(frst_d && !frst_sync[1]) sticky[3]<=1;
   if(free_req_sync[1]!=free_ack) begin
    free_hold<={122'd0,locks_s2,28'd0,sticky,30'd0,frst_sync[1],finit_sync[1],clock_edges,fbeat};
    free_ack<=free_req_sync[1];
   end
  end
 end
 // Observation/snapshot machinery survives DDR reset, but stage events are gated.
 always @(posedge axi_clk or posedge root_rst) begin
  if(root_rst) begin
   axi_req_sync<=0; axi_ack<=0; axi_hold<=0;
   astarts<=0; ars<=0; rs<=0; lasts<=0; enqueues<=0;
   last_ar<=0; last_r<=0; last_meta<=0;
  end else begin
   axi_req_sync<={axi_req_sync[0],req};
    if(!sample_reset) begin
     if(sample_start) astarts<=astarts+1'b1;
     if(sample_ar) begin ars<=ars+1'b1; last_ar<=sample_addr; end
     if(sample_r) begin
      rs<=rs+1'b1; last_r<=sample_data;
      last_meta<={21'd0,sample_len,sample_id,sample_resp,sample_last};
      if(sample_last) lasts<=lasts+1'b1;
    end
     if(sample_enqueue) enqueues<=enqueues+1'b1;
   end
   if(axi_req_sync[1]!=axi_ack) begin
    axi_hold<={sample_debug,last_meta,last_r,last_ar,enqueues,lasts,rs,ars,astarts,
       sample_addr,sample_remain,23'd0,sample_full,sample_last,sample_rready,sample_rvalid,sample_arready,sample_arvalid,sample_started,sample_phase,sample_beat};
    axi_ack<=axi_req_sync[1];
   end
  end
 end
 // Each source holds until its own ack; free polling never waits for AXI.
 // If DDR clock stops, BAR reads continue; age grows and retained data is stale.
 always @(posedge pclk or posedge root_rst) begin
  if(root_rst) begin
   req<=0; free_req<=0; poll<=0; free_ack_sync<=0; axi_ack_sync<=0;
   free_view<=0; axi_view<=0; free_valid<=0; axi_valid<=0;
   free_gen<=0; axi_gen<=0; free_age<=0; axi_age<=0;
  end else begin
   free_ack_sync<={free_ack_sync[0],free_ack};
   axi_ack_sync<={axi_ack_sync[0],axi_ack};
   poll<=poll+1'b1;
   if(poll==255 && axi_ack_sync[1]==req) req<=~req;
   if(poll==255 && free_ack_sync[1]==free_req) free_req<=~free_req;
   if(free_ack_sync[1]!=free_gen) begin
    free_view<=free_hold; free_gen<=free_ack_sync[1]; free_valid<=1; free_age<=0;
   end else if(free_age!=32'hffffffff) free_age<=free_age+1'b1;
   if(axi_ack_sync[1]!=axi_gen) begin
    axi_view<=axi_hold; axi_gen<=axi_ack_sync[1]; axi_valid<=1; axi_age<=0;
   end else if(axi_age!=32'hffffffff) axi_age<=axi_age+1'b1;
  end
 end
 always @(posedge pclk or posedge prst) begin
  if(prst) begin
   pbeat<=0; cmds<=0; last_cmd<=0; last_desc<=0; last_length<=0;
   starts_p<=0; dequeues<=0; msis<=0; grants<=0; msi_d<=0;
   init_sync<=0; reset_sync<=0; rd_data<=0;
  end else begin
   pbeat<=pbeat+1'b1; msi_d<=msi_req;
   init_sync<={init_sync[0],ddr_init}; reset_sync<={reset_sync[0],axi_rst};
   if(cmd_accept) begin cmds<=cmds+1'b1; last_cmd<=cmd_value; end
   if(busy_start) begin starts_p<=starts_p+1'b1; last_desc<=desc_addr; last_length<=desc_length; end
   if(dequeue && !fifo_empty) dequeues<=dequeues+1'b1;
   if(msi_req && !msi_d) msis<=msis+1'b1;
   if(msi_grant) grants<=grants+1'b1;
   if(rd_en) case(rd_addr)
    0: rd_data<={pbeat,32'h134d0001,32'h00010000,32'h53444731};
    1: rd_data<=free_view[127:0];
    2: rd_data<={axi_age,free_age,32'd0,21'd0,reset_sync[1],init_sync[1],axi_valid,free_valid,axi_gen,free_gen,axi_ack_sync[1],free_ack_sync[1],free_req,req,root_rst};
    3: rd_data<={last_length,last_desc,last_cmd,cmds};
    4: rd_data<={grants,msis,dequeues,starts_p};
    5: rd_data<=axi_view[127:0];
    6: rd_data<=axi_view[255:128];
    7: rd_data<=axi_view[383:256];
    8: rd_data<={96'd0,18'd0,msi_req,running,fifo_empty,dequeue,fifo_level};
    9: rd_data<=axi_view[511:384];
     10: rd_data<=free_view[255:128];
     default: rd_data<=128'd0;
   endcase
  end
 end
endmodule
