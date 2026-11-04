`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module  : sccb_diag
// Purpose : after camera configuration completes, read three OV5640 registers over
//           SCCB and latch them for on-screen display:
//             0x300A (ID high), 0x300B (ID low), 0x4300 (output format)
// Notes   : - pure diagnostic; `done` latches high once all three reads finished.
//           - shares the SCCB bus with the config master (open-drain SDA, ANDed SCL).
//////////////////////////////////////////////////////////////////////////////////
module sccb_diag #(
    parameter integer CLK_HZ = 25_000_000,
    parameter integer SCL_HZ = 100_000,
    parameter integer WAIT_MS = 20
)(
    input             clk,
    input             rst_n,
    input             cfg_done,
    output reg  [7:0] id_hi,
    output reg  [7:0] id_lo,
    output reg  [7:0] fmt,
    output reg        done,
    output            ack_err,
    output reg [2:0]  ack_err3,          // per-register latched ack error
    output reg [2:0]  valid3,            // per-register: data valid (rv && !ack_err)
    input      [7:0]  dev_id,          // SCCB 从地址(8bit 写地址, 如 0x78)
    input             sda_in,
    output            sda_low,
    output            scl
);
    localparam integer WAIT_CNT = (CLK_HZ / 1000) * WAIT_MS;

    reg  [31:0] waitcnt;
    reg         start;
    reg  [15:0] ra;
    reg  [1:0]  idx;
    wire [7:0]  rd;
    wire        rv, busy, aerr;
    assign      ack_err = aerr;

    sccb_read_probe #(.CLK_HZ(CLK_HZ), .SCL_HZ(SCL_HZ)) u_probe (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (start),
        .reg_addr (ra),
        .dev_id   (dev_id),
        .rdata    (rd),
        .rdata_valid (rv),
        .busy     (busy),
        .ack_err  (aerr),
        .sda_in   (sda_in),
        .sda_low  (sda_low),
        .scl      (scl)
    );

    localparam S_WAITCFG = 3'd0, S_WAIT = 3'd1, S_GO = 3'd2, S_HOLD = 3'd3, S_DONE = 3'd4;
    reg [2:0] st;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st <= S_WAITCFG; waitcnt <= 32'd0; start <= 1'b0; ra <= 16'h0000;
            idx <= 2'd0; done <= 1'b0; id_hi <= 8'h00; id_lo <= 8'h00; fmt <= 8'h00; valid3 <= 3'd0;
        end
        else begin
            case (st)
            S_WAITCFG: begin
                if (cfg_done) begin
                    st      <= S_WAIT;
                    waitcnt <= 32'd0;
                end
            end
            S_WAIT: begin
                if (waitcnt >= WAIT_CNT) begin
                    ra    <= 16'h300A;
                    idx   <= 2'd0;
                    start <= 1'b1;
                    st    <= S_GO;
                end
                else waitcnt <= waitcnt + 32'd1;
            end
            S_GO: begin
                if (rv) begin
                    // P1-4: only latch data when the transaction had no ACK error;
                    //       otherwise keep the previous value and leave valid3=0.
                    case (idx)
                        2'd0: if (!aerr) begin id_hi <= rd; valid3[0] <= 1'b1; end
                        2'd1: if (!aerr) begin id_lo <= rd; valid3[1] <= 1'b1; end
                        default: if (!aerr) begin fmt <= rd; valid3[2] <= 1'b1; end
                    endcase
                    start <= 1'b0;
                    if (idx == 2'd2) st <= S_DONE;
                    else             st <= S_HOLD;
                end
            end
            S_HOLD: begin
                if (!busy) begin
                    ra    <= (idx == 2'd0) ? 16'h300B : 16'h4300;
                    idx   <= idx + 2'd1;
                    start <= 1'b1;
                    st    <= S_GO;
                end
            end
            S_DONE: begin
                start <= 1'b0;
                done  <= 1'b1;
            end
            default: st <= S_WAITCFG;
            endcase
        end
    end


    // latch per-register ack_err at each read completion (bit0=0x300A, bit1=0x300B, bit2=0x4300)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) ack_err3 <= 3'd0;
        else if (rv) begin
            case (idx)
                2'd0:    ack_err3[0] <= aerr;
                2'd1:    ack_err3[1] <= aerr;
                default: ack_err3[2] <= aerr;
            endcase
        end
    end
endmodule
