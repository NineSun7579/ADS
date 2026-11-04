`timescale 1ns/1ps
module c5_packet_tx (
    input wire clk, input wire rst_n,
    input wire in_valid, output wire in_ready,
    input wire [159:0] in_payload,
    output wire out_valid, input wire out_ready,
    output reg [31:0] out_data, output reg [3:0] out_k
);
    reg busy;
    reg crc_busy;
    reg [4:0] crc_index;
    reg [31:0] crc;
    reg [159:0] crc_shift;
    reg [4:0] index;
    reg [191:0] message;
    reg [7:0] octet;
    function [31:0] byte_crc;
        input [31:0] prior;
        input [7:0] b;
        reg [31:0] c;
        integer j;
        begin
            c=prior ^ {24'd0,b};
            for(j=0;j<8;j=j+1)
                c=c[0] ? ((c>>1)^32'hedb88320) : (c>>1);
            byte_crc=c;
        end
    endfunction
    wire [31:0] crc_next=byte_crc(crc,crc_shift[7:0]);
    assign in_ready=!busy;
    assign out_valid=busy && !crc_busy;
    always @* begin
        octet=0;
        out_data=32'hbce791bc; out_k=4'h9;
        if(index==25) out_data=32'hbce891bc;
        else if(index>=1 && index<=24) begin
            octet=message[(index-1)*8 +: 8];
            out_data={4'h8,octet[7:4],8'hbc,4'h8,octet[3:0],8'hbc};
            out_k=4'h5;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            busy<=0;crc_busy<=0;crc_index<=0;crc<=32'hffffffff;
            crc_shift<=0;index<=0;message<=0;
        end
        else if(!busy) begin
            if(in_valid) begin
                // Acceptance only captures registers; no payload-to-CRC chain.
                message<={32'd0,in_payload};crc_shift<=in_payload;
                crc<=32'hffffffff;crc_index<=0;crc_busy<=1;
                busy<=1;index<=0;
            end
        end else if(crc_busy) begin
            // One byte per cycle, independent of downstream slot readiness.
            crc<=crc_next;crc_shift<={8'd0,crc_shift[159:8]};
            if(crc_index==19) begin
                message[191:160]<=~crc_next;crc_busy<=0;
            end else crc_index<=crc_index+1'b1;
        end else if(out_ready) begin
            if(index==25) begin busy<=0;index<=0;end
            else index<=index+1'b1;
        end
    end
endmodule
