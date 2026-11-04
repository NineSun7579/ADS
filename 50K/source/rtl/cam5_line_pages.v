`timescale 1ns/1ps
// Independent async pixel stream -> two validated native line pages.
// Reset all three clock domains together for a new mode/epoch. Only a complete
// line following SOF is published. Every pixel carries frame/row identity.
module cam5_line_pages #(parameter WIDTH=1280, HEIGHT=720, FIFO_DEPTH=2048)(
    input pclk, p_rst_n, input [15:0] pixel, input de, vs,
    input oclk, o_rst_n, input consume, input [10:0] address,
    output valid, output [15:0] data, output [9:0] row,
    output [7:0] frame, output reg [7:0] latest_frame,
    output reg seen_frame, output fault
);
    reg de_d, vs_d, started, input_fault;
    reg [7:0] frame_id;
    reg [9:0] row_id;
    wire sof=vs && !vs_d;
    wire eol=!de && de_d;
    wire push=sof || (started && (de || eol));
    wire full, empty;
    wire [35:0] token;
    wire pop;
    wire [35:0] incoming = sof ? {2'b10,frame_id+8'd1,10'd0,16'd0} :
        {eol ? 2'b01 : 2'b00,frame_id,row_id,pixel};
    always @(posedge pclk or negedge p_rst_n)
        if (!p_rst_n) begin
            de_d<=0; vs_d<=0; started<=0; input_fault<=0;
            frame_id<=0; row_id<=0;
        end else begin
            de_d<=de; vs_d<=vs;
            if (push && full) input_fault<=1;
            if (sof) begin
                if (de || (started && row_id!=HEIGHT)) input_fault<=1;
                started<=1; frame_id<=frame_id+1'b1; row_id<=0;
            end else if (started && eol) begin
                if (row_id>=HEIGHT) input_fault<=1;
                if (row_id<1023) row_id<=row_id+1'b1;
            end
        end
    cam5_bram_async_fifo #(.WIDTH(36),.DEPTH(FIFO_DEPTH)) fifo(
        .wr_clk(pclk),.wr_rst_n(p_rst_n),.wr_en(push),.wr_data(incoming),.full(full),
        .rd_clk(oclk),.rd_rst_n(o_rst_n),.rd_en(pop),.rd_data(token),.empty(empty));
    (* ASYNC_REG="TRUE" *) reg [1:0] fault_sync;
    reg output_fault;
    assign fault=fault_sync[1] || output_fault;
    reg [15:0] mem0 [0:1279];
    reg [15:0] mem1 [0:1279];
    reg [1:0] ready;
    reg wr_page, rd_page;
    reg [10:0] count;
    reg [9:0] rows [0:1];
    reg [7:0] frames [0:1];
    reg [9:0] filling_row;
    reg [7:0] filling_frame;
    assign valid=ready[rd_page] && !fault;
    assign data=rd_page ? mem1[address] : mem0[address];
    assign row=rows[rd_page];
    assign frame=frames[rd_page];
    assign pop=!empty && !ready[wr_page] && !fault;
    always @(posedge oclk or negedge o_rst_n)
        if (!o_rst_n) begin
            fault_sync<=0; output_fault<=0; latest_frame<=0; seen_frame<=0;
            ready<=0; wr_page<=0; rd_page<=0; count<=0;
            filling_row<=0; filling_frame<=0;
            rows[0]<=0; rows[1]<=0; frames[0]<=0; frames[1]<=0;
        end else begin
            fault_sync<={fault_sync[0],input_fault};
            if (consume && valid) begin ready[rd_page]<=0; rd_page<=~rd_page; end
            if (pop) case (token[35:34])
            2'b10: begin
                if (count!=0) output_fault<=1;
                latest_frame<=token[33:26]; seen_frame<=1; count<=0;
            end
            2'b00: begin
                if (!seen_frame || token[25:16]>=HEIGHT || count>=WIDTH) begin
                    output_fault<=1;
                end else begin
                    if (count==0) begin
                        filling_frame<=token[33:26]; filling_row<=token[25:16];
                    end else if (token[33:26]!=filling_frame ||
                                 token[25:16]!=filling_row) output_fault<=1;
                    if (wr_page) mem1[count]<=token[15:0];
                    else mem0[count]<=token[15:0];
                    count<=count+1'b1;
                end
            end
            2'b01: begin
                if (count!=WIDTH || token[33:26]!=filling_frame ||
                    token[25:16]!=filling_row) begin
                    output_fault<=1;
                end else begin
                    ready[wr_page]<=1; rows[wr_page]<=filling_row;
                    frames[wr_page]<=filling_frame; wr_page<=~wr_page;
                end
                count<=0;
            end
            default: output_fault<=1;
            endcase
        end
endmodule
