// Little-endian RGB565: first pixel in [15:0], eight pixels per full beat.
module display_rgb565_pack128 (
    input wire clk, rst_n,
    input wire [15:0] s_data,
    input wire s_valid, s_last,
    output wire s_ready,
    output reg [127:0] m_data,
    output reg [15:0] m_keep,
    output reg m_valid, m_last,
    input wire m_ready
);
    reg [127:0] partial;
    reg [2:0] lane;
    reg [127:0] assembled;
    always @* begin
        assembled = partial;
        assembled[lane*16 +: 16] = s_data;
    end
    assign s_ready = rst_n && (!m_valid || m_ready);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            partial<=0; lane<=0; m_data<=0; m_keep<=0;
            m_valid<=0; m_last<=0;
        end else if (s_ready) begin
            m_valid<=0; m_last<=0;
            if (s_valid) begin
                if (lane==7 || s_last) begin
                    m_data<=assembled;
                    m_keep<=16'hffff >> (14-2*lane);
                    m_valid<=1; m_last<=s_last;
                    partial<=0; lane<=0;
                end else begin
                    partial<=assembled; lane<=lane+1'b1;
                end
            end
        end
    end
endmodule
