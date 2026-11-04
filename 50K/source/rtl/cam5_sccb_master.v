`timescale 1ns/1ps
// Local-clock SCCB master, open-drain SDA. Checks all four write ACKs or
// all four read-address ACKs. done occurs only after STOP. No retry inference.
module cam5_sccb_master #(parameter DIV=125)(
    input clk, rst_n, start, read_not_write,
    input [15:0] address, input [7:0] write_data,
    output reg busy, done, error, output reg [7:0] read_data,
    output reg scl, inout sda
);
    localparam IDLE=0, START=1, TX=2, ACK=3, RESTART=4,
               RX=5, NACK=6, STOP=7;
    reg [3:0] state;
    reg [1:0] phase;
    reg [15:0] divider;
    reg [2:0] byte_index, bit_index;
    reg [15:0] addr;
    reg [7:0] data, rx;
    reg read_mode, pull_low;
    assign sda = pull_low ? 1'b0 : 1'bz;
    wire [7:0] tx_byte = byte_index==0 ? 8'h78 :
        byte_index==1 ? addr[15:8] : byte_index==2 ? addr[7:0] :
        read_mode ? 8'h79 : data;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            state<=IDLE; phase<=0; divider<=0; byte_index<=0; bit_index<=7;
            addr<=0; data<=0; rx<=0; read_mode<=0; pull_low<=0; scl<=1;
            busy<=0; done<=0; error<=0; read_data<=0;
        end else begin
            done<=0;
            if (state==IDLE) begin
                divider<=0; phase<=0; scl<=1; pull_low<=0;
                if (start) begin
                    addr<=address; data<=write_data; read_mode<=read_not_write;
                    busy<=1; error<=0; byte_index<=0; bit_index<=7; state<=START;
                end
            end else if (divider==DIV-1) begin
                divider<=0; phase<=phase+1'b1;
                case (state)
                START, RESTART: case (phase)
                    0: begin scl<=0; pull_low<=0; end
                    1: scl<=1;
                    2: pull_low<=1;
                    3: begin scl<=0; state<=TX; bit_index<=7; end
                endcase
                TX: case (phase)
                    0: begin scl<=0; pull_low<=~tx_byte[bit_index]; end
                    1: scl<=1;
                    3: begin
                        scl<=0;
                        if (bit_index==0) state<=ACK;
                        else bit_index<=bit_index-1'b1;
                    end
                endcase
                ACK: case (phase)
                    0: begin scl<=0; pull_low<=0; end
                    1: scl<=1;
                    2: if (sda !== 1'b0) error<=1;
                    3: begin
                        scl<=0; bit_index<=7;
                        if (error) state<=STOP;
                        else if (byte_index==3) state<=read_mode ? RX : STOP;
                        else begin
                            byte_index<=byte_index+1'b1;
                            state <= (byte_index==2 && read_mode) ? RESTART : TX;
                        end
                    end
                endcase
                RX: case (phase)
                    0: begin scl<=0; pull_low<=0; end
                    1: scl<=1;
                    2: rx<={rx[6:0],sda};
                    3: begin
                        scl<=0;
                        if (bit_index==0) begin read_data<=rx; state<=NACK; end
                        else bit_index<=bit_index-1'b1;
                    end
                endcase
                NACK: case (phase)
                    0: begin scl<=0; pull_low<=0; end
                    1: scl<=1;
                    3: begin scl<=0; state<=STOP; end
                endcase
                STOP: case (phase)
                    0: begin scl<=0; pull_low<=1; end
                    1: scl<=1;
                    2: pull_low<=0;
                    3: begin busy<=0; done<=1; state<=IDLE; end
                endcase
                endcase
            end else divider<=divider+1'b1;
        end
endmodule
