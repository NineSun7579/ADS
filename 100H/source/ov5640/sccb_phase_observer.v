// Passive observation only. All events use the existing native dri_clk edge.
module sccb_phase_observer (
 input clk,
 input rst_n,
 (* syn_maxfan = 8 *) input take,
 (* syn_maxfan = 8 *) input busy,
 input [31:0] accepted_seq, accepted_payload,
 input [7:0] state,
 input [6:0] count,
 input sda, scl, oe, engine_exec,
 input [15:0] engine_addr,
 input engine_rw,
 input [7:0] engine_wdata,
 input done,
 input [7:0] raw_byte,
 input ack,
 output reg [511:0] snapshot,
 output reg event_done
);
 reg [31:0] ticks, take_id, take_payload, loaded_payload, completions;
 reg [31:0] take_time, load_time, plane0, plane1, plane2, plane3;
 reg [7:0] samples;
 reg [3:0] ack_bits;
 reg [7:0] flags;
 reg active, load_pending;
 reg [31:0] last_id;
 integer slot, phase;
 reg [31:0] observation;
 always @* begin
   slot=-1; phase=0;
   if(state==8'h20 && count>=36 && count<=39) begin slot=0; phase=count-36; end
   if(state==8'h40 && count<=35) begin slot=1+(count/4); phase=count%4; end
   observation=0;
   if(slot>=0 && slot<=9) begin
     observation[slot]=sda;
     observation[10+slot]=scl;
     observation[20+slot]=oe;
   end
 end
 always @(posedge clk or negedge rst_n) begin
   if(!rst_n) begin
     ticks<=0; take_id<=0; take_payload<=0; loaded_payload<=0; completions<=0;
     take_time<=0; load_time<=0; plane0<=0; plane1<=0; plane2<=0; plane3<=0;
     samples<=0; ack_bits<=0; flags<=0; active<=0; load_pending<=0;
     snapshot<=0; event_done<=0; last_id<=0;
   end else begin
     ticks<=ticks+1'b1; event_done<=0;
     if(take) begin
       take_id<=accepted_seq; take_payload<=accepted_payload; take_time<=ticks;
       plane0<=0; plane1<=0; plane2<=0; plane3<=0; samples<=0; ack_bits<=0;
       flags<={3'b0,active,accepted_seq != last_id+1'b1,
               accepted_seq==last_id, !(state==8'h01 && engine_exec),1'b0};
       last_id<=accepted_seq; active<=1; load_pending<=1;
     end
     // One edge AFTER actual engine exec captures addr_t/wr_flag/data_wr_t.
     if(load_pending) begin
       loaded_payload<={7'd0,engine_rw,engine_addr,engine_wdata};
       if({7'd0,engine_rw,engine_addr,engine_wdata} != take_payload) flags[6]<=1;
       load_time<=ticks; load_pending<=0;
     end
     if(active) begin
       if(accepted_seq != take_id) flags[7]<=1;
       if(engine_exec && !take) flags[5]<=1;
       if(state==8'h20 && count==2) flags[0]<=1; // repeated START context
       if(slot>=0 && slot<=9) begin
         case(phase)
          0: plane0 <= plane0 | observation;
          1: plane1 <= plane1 | observation;
          2: plane2 <= plane2 | observation;
          3: plane3 <= plane3 | observation;
         endcase
       end
        // SCC2 ABI: run7 samples at counts 2,6,...30 (plane 2).
        if(state==8'h40 && count<=30 && count%4==2) samples<=samples+1'b1;
       if(state==8'h02 && count==38) ack_bits[0]<=sda;
       if(state==8'h04 && count==34) ack_bits[1]<=sda;
       if(state==8'h08 && count==34) ack_bits[2]<=sda;
       if(state==8'h20 && count==38) ack_bits[3]<=sda;
     end
     // A stale/duplicate done or reset-abandoned transfer cannot manufacture
     // a diagnostic completion. The functional engine is never gated here.
     if(done && busy && active) begin
       completions<=completions+1'b1;
       snapshot<=0;
       snapshot[4*32 +:32]<=take_id;
       snapshot[5*32 +:32]<=take_payload;
       snapshot[6*32 +:32]<=loaded_payload;
       snapshot[7*32 +:32]<=completions+1'b1;
       snapshot[8*32 +:32]<={2'd0,!active,flags,ack_bits,samples,ack,raw_byte};
       snapshot[9*32 +:32]<=plane0;
       snapshot[10*32+:32]<=plane1;
       snapshot[11*32+:32]<=plane2;
       snapshot[12*32+:32]<=plane3;
       snapshot[13*32+:32]<=take_time;
       snapshot[14*32+:32]<=ticks;
       snapshot[15*32+:32]<=load_time;
       event_done<=1; active<=0;
     end
   end
 end
endmodule
