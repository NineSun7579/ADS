`timescale 1ns/1ps
// One outstanding item. Both resets must assert together; release is local.
// Data is held from request until the returned acknowledgement. The extra
// destination settling cycle follows two synchronizer stages on the toggle.
module cam5_bundle_cdc #(parameter WIDTH=9)(
    input s_clk, s_rst_n, input [WIDTH-1:0] s_data, input s_valid,
    output s_ready, input d_clk, d_rst_n,
    output reg [WIDTH-1:0] d_data, output reg d_valid, input d_ready
);
    reg [WIDTH-1:0] held;
    reg req, ack;
    (* ASYNC_REG="TRUE" *) reg [1:0] ack_sync, req_sync;
    reg settling;
    assign s_ready = (req == ack_sync[1]);
    always @(posedge s_clk or negedge s_rst_n)
        if (!s_rst_n) begin held<=0; req<=0; ack_sync<=0; end
        else begin
            ack_sync <= {ack_sync[0],ack};
            if (s_valid && s_ready) begin held<=s_data; req<=~req; end
        end
    always @(posedge d_clk or negedge d_rst_n)
        if (!d_rst_n) begin
            req_sync<=0; ack<=0; settling<=0; d_valid<=0; d_data<=0;
        end else begin
            req_sync <= {req_sync[0],req};
            if (d_valid) begin
                if (d_ready) begin d_valid<=0; ack<=req_sync[1]; end
            end else if (settling) begin
                d_data<=held; d_valid<=1; settling<=0;
            end else if (req_sync[1] != ack) settling<=1;
        end
endmodule
