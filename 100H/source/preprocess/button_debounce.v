//============================================================================
// button_debounce.v : 按键消抖 (Ntractive 三级同步 + 稳定计数)
// 输出: 稳定电平 level + 翻转脉冲 toggle (供 BUTTON_STATUS 置位)
// 默认参数 50MHz 下约 20ms 稳定期
//============================================================================
module button_debounce #(
    parameter STABLE_CYCLES = 20'd1_000_000   // 20ms @ 50MHz
)(
    input  wire clk,
    input  wire rst_n,
    input  wire btn_in,              // 原始按键 (按下电平由板级决定, 此处高有效)
    output reg  btn_level,           // 消抖后稳定电平
    output reg  btn_toggle,          // 每次电平变化打1拍脉冲
    output wire btn_pressed          // 组合: 当前按住
);

    reg [1:0] sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) sync <= 2'b00;
        else        sync <= {sync[0], btn_in};
    end
    wire sample = &sync;             // 两拍同为高才算按下

    reg [19:0] cnt;
    reg        state;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt   <= 20'd0;
            state <= 1'b0;
        end else if (sample == state) begin
            cnt <= 20'd0;
        end else begin
            cnt <= cnt + 1'b1;
            if (cnt >= STABLE_CYCLES) begin
                state <= sample;
                cnt   <= 20'd0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_level  <= 1'b0;
            btn_toggle <= 1'b0;
        end else begin
            btn_level  <= state;
            btn_toggle <= (state != btn_level);
        end
    end

    assign btn_pressed = btn_level;

endmodule
