// Native META scheduler. meta_sent pulses once the whole META packet has been
// accepted by the forward mux; the capture read side holds the matching SOF
// until then, so video is never reset to enforce ordering.
module cam5_native_control_mux(
    input wire clk,input wire rst_n,
    input wire meta_valid,output wire meta_ready,input wire [159:0] meta_payload,
    input wire control_ready,output wire control_valid,
    output wire [31:0] control_data,output wire [3:0] control_k,
    output reg meta_sent,
    input wire diag_valid,output wire diag_ready,input wire [159:0] diag_payload
);
    reg pending,packet_active,packet_seen,packet_meta;
    reg [159:0] payload;
    assign meta_ready=!pending && !packet_active;
    assign diag_ready=meta_ready && !meta_valid;
    wire in_ready;
    wire out_valid;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin pending<=0;packet_active<=0;packet_seen<=0;payload<=0;meta_sent<=0;packet_meta<=0;end
        else begin
            meta_sent<=0;
            if(meta_valid && meta_ready)begin pending<=1;payload<=meta_payload;packet_meta<=1;end
            else if(diag_valid && diag_ready)begin pending<=1;payload<=diag_payload;packet_meta<=0;end
            if(pending && in_ready)begin pending<=0;packet_active<=1;packet_seen<=0;end
            if(packet_active && out_valid)packet_seen<=1;
            if(packet_active && packet_seen && !out_valid)begin packet_active<=0;meta_sent<=packet_meta;end
        end
    end
    assign control_valid=out_valid;
    c5_packet_tx packet(.clk(clk),.rst_n(rst_n),.in_valid(pending),.in_ready(in_ready),
        .in_payload(payload),.out_valid(out_valid),.out_ready(control_ready),
        .out_data(control_data),.out_k(control_k));
endmodule
