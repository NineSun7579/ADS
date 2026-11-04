// RX clock-domain publication fence. Request/reply bundles cross elsewhere.
// Cut C is a packet-idle edge after ordered raster frontier covers the request.
// Raw E0 ingress -> E1 rejection -> E2 count -> E3 runtime fault -> E4 visible.
// Four explicit drain stages after C cover those registered producer stages;
// this is NOT an AXI timer or an assumption about unrelated clock ratios.
// C is the linearization point. Reply produced at C+4 certifies health THROUGH
// C inclusive; some later faults are conservatively included. Faults after C
// do not retroactively change that cutoff and remain sticky at runtime.
module c5_rx_health_fence(
 input wire clk,rst_n,request_valid,output wire request_ready,
 input wire [63:0] request_data,
 input wire [31:0] epoch,verified_frontier,error_count,
 input wire running,packet_active,ordered_busy,packet_fault,raster_fault,decode_fault,link_ok,
 output reg reply_valid,input wire reply_ready,output wire [64:0] reply_data
);
 reg [2:0] stage;reg [63:0] held;reg [31:0] cutoff_errors;
 reg reply_health;
 assign reply_data={reply_health,held};
 wire healthy=running && link_ok && !packet_fault && !raster_fault && !decode_fault;
 assign request_ready=(stage==0 && !reply_valid);
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin stage<=0;held<=0;cutoff_errors<=0;reply_valid<=0;reply_health<=0;end
  else begin
   if(reply_valid && reply_ready)reply_valid<=0;
   case(stage)
    0:if(request_valid && request_ready)begin held<=request_data;stage<=1;end
    1:begin
     // Snapshot CE depends only on local stage; no link/health->32bit CE.
     cutoff_errors<=error_count;
     if(held[63:32]!=epoch || !healthy)begin reply_health<=0;reply_valid<=1;stage<=0;end
     else if(!packet_active && !ordered_busy && verified_frontier>=held[31:0] && held[31:0]!=0)begin
       stage<=2;
     end
    end
    2:stage<=3; // codec counter stage
    3:stage<=4; // runtime error comparison/sticky stage
     4:stage<=5; // added aligned ingress stage drains before health decision
     5:begin // producer stages are visible; only health BIT is captured here
     // Valid next traffic after C cannot invalidate the latched idle/drained
     // cutoff. Actual faults remain conservatively included through sampling.
      reply_health<=healthy && error_count==cutoff_errors &&
        held[63:32]==epoch && verified_frontier>=held[31:0];
     reply_valid<=1;stage<=0;
    end
   endcase
  end
 end
endmodule
