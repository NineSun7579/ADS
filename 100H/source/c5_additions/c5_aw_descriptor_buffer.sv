// One irrevocable descriptor. Only the surrounding global AXI reset clears it.
// No fall-through, simultaneous refill, or downstream READY -> upstream READY.
module c5_aw_descriptor_buffer (
    input wire clk, rst,
    input wire [56:0] u_payload,
    input wire u_valid,
    output wire u_ready,
    output reg [56:0] d_payload,
    output wire d_valid,
    input wire d_ready,
    output reg pending
);
    assign u_ready = !rst && !pending;
    assign d_valid = !rst && pending;
    always @(posedge clk) begin
        if (rst) pending <= 1'b0;
        else if (u_valid && u_ready) begin
            d_payload <= u_payload;
            pending <= 1'b1;
        end else if (d_valid && d_ready) pending <= 1'b0;
    end
endmodule
