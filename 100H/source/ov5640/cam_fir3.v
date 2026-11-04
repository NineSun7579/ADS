// cam_fir3.v -- transparent 3-tap FIR ([1 2 1] / 4) for the cam1 RGB565 stream.
// Replaces the Pango ipsxe FIR IP whose encrypted core drops beats on the real
// camera stream (tlast/gap handling), wedging the DDR write packer.
//
//   y[n] = (x[n] + 2*x[n-1] + x[n-2]) >> 2   per R/G/B channel, unsigned
//
// One-cycle latency, taps shift only on valid beats (gap-robust), one output
// beat per input beat: the W*H+1-pixel frame contract of the ov5640_ddr packer
// is bit-identical to a bypass apart from pixel values.
module cam_fir3 #(
    parameter DATA_WIDTH = 16   // RGB565
)(
    input  wire                    clk,
    input  wire                    rst,

    input  wire                    in_valid,
    input  wire [DATA_WIDTH-1:0]   in_pixel,
    input  wire                    in_vsync,

    output reg                     out_valid,
    output reg  [DATA_WIDTH-1:0]   out_pixel,
    output reg                     out_vsync
);

    // previous two valid samples per channel (x[n-1], x[n-2])
    reg [4:0] r1, r2;
    reg [5:0] g1, g2;
    reg [4:0] b1, b2;

    // x[n] + 2*x[n-1] + x[n-2]:
    //   R/B 5-bit taps: max 31 + 62 + 31 = 124 -> 7 bits
    //   G   6-bit taps: max 63 + 126 + 63 = 252 -> 8 bits
    wire [6:0] sum_r = {2'b00, in_pixel[15:11]} + {1'b0, r1, 1'b0} + {2'b00, r2};
    wire [7:0] sum_g = {2'b00, in_pixel[10:5]}  + {1'b0, g1, 1'b0} + {2'b00, g2};
    wire [6:0] sum_b = {2'b00, in_pixel[4:0]}   + {1'b0, b1, 1'b0} + {2'b00, b2};

    always @(posedge clk) begin
        if (rst) begin
            out_valid <= 1'b0;
            out_vsync <= 1'b0;
            {r1, r2, g1, g2, b1, b2} <= 24'h0;
        end
        else begin
            out_valid <= in_valid;
            out_vsync <= in_vsync;
            out_pixel <= {sum_r[6:2], sum_g[7:2], sum_b[6:2]};
            if (in_valid) begin
                r1 <= in_pixel[15:11]; r2 <= r1;
                g1 <= in_pixel[10:5];  g2 <= g1;
                b1 <= in_pixel[4:0];   b2 <= b1;
            end
        end
    end

endmodule
