// Unsigned 64/64 restoring divider. One bit per cycle, exact quotient and
// remainder. start is accepted only while idle; done pulses with the result.
// Controlled alternative to the official Pango Divider for comparison.
module lane_divider_iterative (
    input  wire         clk,
    input  wire         rst_n,
    input  wire [63:0]  dividend,
    input  wire [63:0]  divisor,
    input  wire         start,
    output wire         ready,
    output reg          done,
    output reg  [63:0]  quotient,
    output reg  [63:0]  remainder
);
    reg active;
    reg [5:0] count;
    reg [63:0] divisor_q;
    reg [64:0] rem_q;
    reg [63:0] quotient_q;
    assign ready = !active;

    wire [64:0] shifted_rem = {rem_q[63:0], quotient_q[63]};
    // One 66-bit subtractor gives both the trial remainder and the borrow;
    // a separate >= comparator would put two carry chains on this path.
    wire [65:0] trial_rem = {1'b0, shifted_rem} - {2'b0, divisor_q};
    wire subtract = !trial_rem[65];
    wire [64:0] next_rem = subtract ? trial_rem[64:0] : shifted_rem;
    wire [63:0] next_q = {quotient_q[62:0], subtract};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active <= 0;
            count <= 0;
            divisor_q <= 0;
            rem_q <= 0;
            quotient_q <= 0;
            quotient <= 0;
            remainder <= 0;
            done <= 0;
        end else begin
            done <= 0;
            if (!active) begin
                if (start) begin
                    active <= 1;
                    count <= 0;
                    divisor_q <= divisor;
                    rem_q <= 0;
                    quotient_q <= dividend;
                end
            end else begin
                rem_q <= next_rem;
                quotient_q <= next_q;
                if (count == 63) begin
                    active <= 0;
                    quotient <= next_q;
                    remainder <= next_rem[63:0];
                    done <= 1;
                end else begin
                    count <= count + 1'b1;
                end
            end
        end
    end
endmodule
