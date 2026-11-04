// Even WIDTH x HEIGHT RGB565 -> WIDTH/2 x HEIGHT/2 display side branch.
// Frames contain exactly WIDTH*HEIGHT accepted beats, beginning after reset.
module rgb565_display_decimator #(
    parameter integer WIDTH = 640, HEIGHT = 480
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] s_pixel,
    input  wire        s_valid,
    output wire        s_ready,
    output reg  [15:0] m_pixel,
    output reg         m_valid,
    input  wire        m_ready,
    output reg         m_sof,
    output reg         m_eof
);
    localparam integer X_BITS = WIDTH > 1 ? $clog2(WIDTH) : 1;
    localparam integer Y_BITS = HEIGHT > 1 ? $clog2(HEIGHT) : 1;
    reg [X_BITS-1:0] x;
    reg [Y_BITS-1:0] y;

    // One elastic output slot. Conservative stalls also stop discarded beats.
    assign s_ready = rst_n && (!m_valid || m_ready);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x <= 0;
            y <= 0;
            m_pixel <= 0;
            m_valid <= 0;
            m_sof <= 0;
            m_eof <= 0;
        end else if (s_ready) begin
            // Consumed slot can be replaced on this same clock edge.
            m_valid <= 0;
            m_sof <= 0;
            m_eof <= 0;
            if (s_valid) begin
                if (!x[0] && !y[0]) begin
                    m_pixel <= s_pixel;
                    m_valid <= 1;
                    m_sof <= (x == 0 && y == 0);
                    m_eof <= (x == WIDTH-2 && y == HEIGHT-2);
                end
                if (x == WIDTH-1) begin
                    x <= 0;
                    if (y == HEIGHT-1)
                        y <= 0;
                    else
                        y <= y + 1'b1;
                end else begin
                    x <= x + 1'b1;
                end
            end
        end
    end
endmodule
