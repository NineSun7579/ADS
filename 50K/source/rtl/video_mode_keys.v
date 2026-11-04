`timescale 1ns/1ps
module video_mode_keys #(parameter DEBOUNCE_CYCLES = 500000)(
    input clk, input rst_n, input key1_n, input key2_n,
    output reg hdmi_request
);
    localparam CW = (DEBOUNCE_CYCLES < 2) ? 1 : $clog2(DEBOUNCE_CYCLES);
    (* ASYNC_REG = "TRUE" *) reg [1:0] k1_sync, k2_sync;
    reg k1_stable, k2_stable;
    reg [CW-1:0] count1, count2;
    wire press1 = !k1_sync[1] && k1_stable && count1 == DEBOUNCE_CYCLES-1;
    wire press2 = !k2_sync[1] && k2_stable && count2 == DEBOUNCE_CYCLES-1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            k1_sync <= 2'b11; k2_sync <= 2'b11;
            k1_stable <= 1'b1; k2_stable <= 1'b1;
            count1 <= 0; count2 <= 0; hdmi_request <= 1'b0;
        end else begin
            k1_sync <= {k1_sync[0],key1_n};
            k2_sync <= {k2_sync[0],key2_n};
            if (k1_sync[1] == k1_stable) count1 <= 0;
            else if (count1 == DEBOUNCE_CYCLES-1) begin
                k1_stable <= k1_sync[1]; count1 <= 0;
            end else count1 <= count1 + 1'b1;
            if (k2_sync[1] == k2_stable) count2 <= 0;
            else if (count2 == DEBOUNCE_CYCLES-1) begin
                k2_stable <= k2_sync[1]; count2 <= 0;
            end else count2 <= count2 + 1'b1;
            // KEY2 wins simultaneous presses and remains dominant while held.
            // Release never changes the latched mode.
            if (press2) hdmi_request <= 1'b1;
            else if (press1 && k2_stable && k2_sync[1]) hdmi_request <= 1'b0;
        end
    end
endmodule
