`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module  : sccb_read_probe
// Purpose : diagnostic SCCB (I2C-compatible) read master for OV5640.
//           Reads one 16-bit register over a shared open-drain bus.
// Notes   :
//   - SDA is open-drain: only pulls low (sda_low=1), samples via sda_in.
//   - SCL is driven push-pull; the caller ANDs it with the config master's SCL
//     so that the config master holding SCL high does not fight this one.
//   - One read per `start` level.  `rdata_valid` pulses when rdata is ready.
//   - `ack_err` latches if a slave ACK was not seen (device missing / SCCB open).
//   - Timing: 4 quarter-periods per SCL period (ph 0..3).
//       ph0 : SCL low , set SDA
//       ph1 : SCL high (slave samples on rising edge)
//       ph2 : SCL high (master samples sda_in for reads/ACKs)
//       ph3 : end of period -> advance
//////////////////////////////////////////////////////////////////////////////////
module sccb_read_probe #(
    parameter integer CLK_HZ = 25_000_000,
    parameter integer SCL_HZ = 100_000
)(
    input             clk,
    input             rst_n,
    input             start,          // level: begin one read
    input      [15:0] reg_addr,       // register address (MSB first on the wire)
    input      [7:0]  dev_id,         // 8-bit device address, e.g. 0x78
    output reg  [7:0] rdata,
    output reg        rdata_valid,
    output reg        busy,
    output reg        ack_err,        // 1 = any transaction ACK was missing (aggregate)
    output reg [3:0]  ack_err4,       // per-phase: [0]dev+W [1]reg_hi [2]reg_lo [3]dev+R
    input             sda_in,
    output reg        sda_low,        // open drain: 1 = pull SDA low
    output reg        scl
);

    // ---- quarter-period tick ----
    localparam integer DIV = (CLK_HZ / (SCL_HZ * 4) < 2) ? 2 : (CLK_HZ / (SCL_HZ * 4));
    reg  [15:0] divcnt;
    reg  [1:0]  ph;
    wire        tick = (divcnt == DIV - 1);

    // [FIX] hold phase while idle: after start, run begins cleanly at ph=0

    localparam S_IDLE = 2'd0, S_RUN = 2'd1, S_DONE = 2'd2;
    reg  [1:0] fsm;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            divcnt <= 16'd0;
            ph     <= 2'd0;
        end
        else if (fsm == S_IDLE) begin
            divcnt <= 16'd0;      // [FIX] idle: hold phase
            ph     <= 2'd0;
        end
        else begin
            divcnt <= tick ? 16'd0 : divcnt + 16'd1;
            if (tick) ph <= ph + 2'd1;
        end
    end
    wire eop = tick && (ph == 2'd3);          // end of an SCL period

    // ---- operation sequence (every TX/RX byte is followed by an ACK bit) ----
    localparam OP_START = 4'd0,
               OP_TX1   = 4'd1,               // 0x78 (device addr + write)
               OP_ACK1  = 4'd2,
               OP_TX2   = 4'd3,               // reg_addr[15:8]
               OP_ACK2  = 4'd4,
               OP_TX3   = 4'd5,               // reg_addr[7:0]
               OP_ACK3  = 4'd6,
               OP_RST   = 4'd7,               // repeated START
               OP_TXR   = 4'd8,               // 0x79 (device addr + read)
               OP_ACK4  = 4'd9,
               OP_RX    = 4'd10,
               OP_NAK   = 4'd11,
               OP_STOP  = 4'd12;


    reg  [3:0] op;
    reg  [2:0] bitc;
    reg  [7:0] rxsh;

    wire is_tx = (op == OP_TX1) || (op == OP_TX2) || (op == OP_TX3) || (op == OP_TXR);
    wire is_rx = (op == OP_RX);
    wire is_ack = (op == OP_ACK1) || (op == OP_ACK2) || (op == OP_ACK3) || (op == OP_ACK4);

    reg [7:0] txsh;
    always @(*) begin
        case (op)
            OP_TX1:  txsh = dev_id;
            OP_TX2:  txsh = reg_addr[15:8];
            OP_TX3:  txsh = reg_addr[7:0];
            OP_TXR:  txsh = {dev_id[7:1], 1'b1};
            default: txsh = 8'hFF;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fsm         <= S_IDLE;
            op          <= OP_START;
            bitc        <= 3'd0;
            scl         <= 1'b1;
            sda_low     <= 1'b0;
            busy        <= 1'b0;
            rdata       <= 8'd0;
            rdata_valid <= 1'b0;
            ack_err     <= 1'b0;
            ack_err4    <= 4'd0;
            rxsh        <= 8'd0;
        end
        else begin
            rdata_valid <= 1'b0;
            case (fsm)
            S_IDLE: begin
                scl     <= 1'b1;
                sda_low <= 1'b0;
                busy    <= 1'b0;
                if (start) begin
                    fsm     <= S_RUN;
                    op      <= OP_START;
                    bitc    <= 3'd0;
                    busy    <= 1'b1;
                    ack_err <= 1'b0;
                    ack_err4<= 4'd0;
                end
            end

            S_RUN: begin
                if (eop) begin
                    scl <= 1'b0;
                    if (is_tx && (bitc == 3'd7)) begin
                        op   <= op + 4'd1;
                        bitc <= 3'd0;
                    end
                    else if (is_rx && (bitc == 3'd7)) begin
                        rdata       <= rxsh;        // rxsh already shifted in 8 bits
                        rdata_valid <= 1'b1;
                        op          <= OP_NAK;
                        bitc        <= 3'd0;
                    end
                    else if (!is_tx && !is_rx) begin
                        op   <= op + 4'd1;
                        bitc <= 3'd0;
                    end
                    else begin
                        bitc <= bitc + 3'd1;
                    end

                    if (op == OP_STOP) fsm <= S_DONE;
                end
                else if (tick) begin
                    // phase actions run once per quarter period (tick), not every clock
                    case (ph)
                    2'd0: begin
                        // START/RESTART: keep SCL high and SDA high, then drop SDA on ph1
                        if ((op == OP_START) || (op == OP_RST)) begin
                            scl     <= 1'b1;
                            sda_low <= 1'b0;
                        end
                        else begin
                            scl <= 1'b0;
                            if (is_tx)              sda_low <= ~txsh[3'd7 - bitc];
                            else if (op == OP_STOP) sda_low <= 1'b1;  // hold SDA low
                            else                    sda_low <= 1'b0;  // ACK/RX/NAK release
                        end
                    end
                    2'd1: begin
                        scl <= 1'b1;
                        if ((op == OP_START) || (op == OP_RST)) sda_low <= 1'b1; // SDA falls, SCL high
                    end
                    2'd2: begin
                        if ((op == OP_START) || (op == OP_RST)) begin
                            scl <= 1'b0;                 // SCL falls after START
                        end
                        else begin
                            scl <= 1'b1;
                            if (is_rx)  rxsh <= {rxsh[6:0], sda_in};
                            if (is_ack && sda_in) begin              // NAK from slave
                                ack_err <= 1'b1;
                                case (op)
                                    OP_ACK1: ack_err4[0] <= 1'b1;
                                    OP_ACK2: ack_err4[1] <= 1'b1;
                                    OP_ACK3: ack_err4[2] <= 1'b1;
                                    default: ack_err4[3] <= 1'b1;
                                endcase
                            end
                            if (op == OP_STOP) sda_low <= 1'b0;      // SDA rises, SCL high
                        end
                    end
                    2'd3: ; // hold
                    endcase
                end
            end

            S_DONE: begin
                scl     <= 1'b1;
                sda_low <= 1'b0;
                busy    <= 1'b0;
                if (!start) fsm <= S_IDLE;
            end
            endcase
        end
    end

endmodule
