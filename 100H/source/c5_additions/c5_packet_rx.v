`timescale 1ns/1ps
module c5_packet_rx #(
    parameter ALIGN_BYTES=1,
    parameter integer TIMEOUT_CYCLES=65536
) (
    input wire clk, input wire rst_n, input wire link_ok,
    input wire [31:0] in_data, input wire [3:0] in_k, input wire in_valid,
    output reg out_valid, output reg [159:0] out_payload,
    output reg [31:0] error_count, output wire packet_active,
    // Diagnostics: a CRC-good packet of type 2 (native META) was accepted / rejected
    output reg native_ok, output reg native_bad
);
    reg [31:0] previous_data;
    reg [3:0] previous_k;
    reg previous_valid, aligned;
    reg [1:0] rotation;
    wire [63:0] window_data={in_data,previous_data};
    wire [7:0] window_k={in_k,previous_k};
    reg [31:0] symbol_data;
    reg [3:0] symbol_k;
    reg symbol_valid, start_found;
    reg [1:0] found_rotation;
    integer lane;
    always @* begin
        symbol_data=in_data;symbol_k=in_k;symbol_valid=in_valid;
        start_found=0;found_rotation=rotation;
        if(ALIGN_BYTES) begin
            symbol_valid=in_valid && previous_valid && aligned;
            symbol_data=window_data >> (rotation*8);
            symbol_k=window_k >> rotation;
            for(lane=3;lane>=0;lane=lane-1) begin
                if(in_valid && previous_valid &&
                   ((window_data >> (lane*8)) & 64'hffffffff)==64'hbce791bc &&
                   ((window_k >> lane) & 8'h0f)==8'h09) begin
                    start_found=1;found_rotation=lane;
                end
            end
            if(start_found) begin
                symbol_data=32'hbce791bc;symbol_k=9;symbol_valid=1;
            end
        end
    end
    wire is_start=symbol_k==9 && symbol_data==32'hbce791bc;
    wire is_end=symbol_k==9 && symbol_data==32'hbce891bc;
    wire is_byte=symbol_k==5 && symbol_data[7:0]==8'hbc &&
        symbol_data[23:16]==8'hbc && symbol_data[15:12]==4'h8 &&
        symbol_data[31:28]==4'h8;
    wire [7:0] octet={symbol_data[27:24],symbol_data[11:8]};
    wire is_idle=(symbol_k==5 && (symbol_data==32'hc5bcc5bc ||
        symbol_data==32'h28bc28bc || symbol_data==32'h50bc50bc ||
        symbol_data==32'hffbcffbc)) ||
        (symbol_k==9 && (symbol_data & 32'hff9fffff)==32'hbc0028bc);
    reg active;
    reg [4:0] count;
    reg [159:0] payload;
    reg [31:0] crc,received_crc;
    // Parameter 0 has the same one-clock minimum semantics as parameter 1.
    localparam integer AGE_WIDTH=(TIMEOUT_CYCLES<2 ? 1 : $clog2(TIMEOUT_CYCLES));
    localparam integer AGE_LIMIT=(TIMEOUT_CYCLES<2 ? 0 : TIMEOUT_CYCLES-1);
    reg [AGE_WIDTH-1:0] age;
    reg error_event;
    // No decode-driven counter CE: the registered event feeds an always
    // clocked adder. Publication is one clock after rejection, modulo 2^32.
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) error_count<=0;
        else error_count<=error_count+{31'd0,error_event};
    end
    assign packet_active=link_ok && (active || (symbol_valid && is_start));
    function [31:0] byte_crc;
        input [31:0] c0; input [7:0] b;
        reg [31:0] c; integer j;
        begin
            c=c0 ^ {24'd0,b};
            for(j=0;j<8;j=j+1)
                c=c[0] ? ((c>>1)^32'hedb88320) : (c>>1);
            byte_crc=c;
        end
    endfunction
    wire header_ok=(payload[7:0]==1 && payload[15:8]>=1 && payload[15:8]<=6 &&
        payload[23:16]==5 && payload[31:24]<=1 && payload[63:32]!=0 &&
        payload[111:96]==640 && payload[127:112]==480 &&
        ((payload[31:24]==0 && payload[79:64]==640 && payload[95:80]==480) ||
         (payload[31:24]==1 && payload[79:64]==1280 && payload[95:80]==720))) ||
        // Native HDMI META v2: type 2, kind 6 (META), source 5, mode in [25:24];
        // exact 1280x480 or 1280x960, reserved [127:96] zero, nonzero gen/frame.
        (payload[7:0]==2 && payload[15:8]==6 && payload[23:16]==5 && payload[31:26]==0 &&
         payload[63:32]!=0 && payload[127:96]==0 && payload[159:128]!=0 &&
         ((payload[25:24]==2 && payload[79:64]==1280 && payload[95:80]==480) ||
           (payload[25:24]==3 && payload[79:64]==1280 && payload[95:80]==960))) ||
        // Diagnostic heartbeat: independent of native format qualification.
        (payload[31:0]==32'h00050703);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            previous_data<=0;previous_k<=0;previous_valid<=0;aligned<=0;rotation<=0;
            active<=0;count<=0;payload<=0;crc<=32'hffffffff;received_crc<=0;
            age<=0;out_valid<=0;out_payload<=0;error_event<=0;native_ok<=0;native_bad<=0;
        end else begin
            out_valid<=0;native_ok<=0;native_bad<=0;
            error_event<=0;
            if(!link_ok) begin
                previous_valid<=0;aligned<=0;active<=0;count<=0;age<=0;
                if(active) error_event<=1;
            end else begin
                if(in_valid) begin
                    previous_data<=in_data;previous_k<=in_k;previous_valid<=1;
                end
                if(start_found) begin aligned<=1;rotation<=found_rotation;end
                if(symbol_valid && is_start) begin
                    if(active) error_event<=1;
                    active<=1;count<=0;payload<=0;received_crc<=0;
                    crc<=32'hffffffff;age<=0;
                end else if(active) begin
                    // Hold at the limit; the timeout decision uses the old age.
                    // Byte acceptance below still overrides this with zero.
                    if(age<AGE_LIMIT) age<=age+1'b1;
                    if(symbol_valid && is_end) begin
                        active<=0;
                        if(count==24 && received_crc==~crc && header_ok) begin
                            out_payload<=payload;out_valid<=1;
                            if(payload[7:0]==8'd2)native_ok<=1;
                        end else begin
                            error_event<=1;
                            if(count==24 && received_crc==~crc && payload[7:0]==8'd2)native_bad<=1;
                        end
                    end else if(symbol_valid && is_byte) begin
                        if(count<24) begin
                            if(count<20) begin
                                payload[count*8 +: 8]<=octet;
                                crc<=byte_crc(crc,octet);
                            end else received_crc[(count-20)*8 +: 8]<=octet;
                            count<=count+1'b1;age<=0;
                        end else begin active<=0;error_event<=1;end
                    end else if(symbol_valid && !is_idle) begin
                        active<=0;error_event<=1;
                    end else if(age>=AGE_LIMIT) begin
                        active<=0;error_event<=1;
                    end
                end
            end
        end
    end
endmodule
