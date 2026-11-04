// Native HDMI geometry/publication descriptor. The producer publishes one
// complete AXI-domain snapshot; the read side returns it through a bit-serial snapshot CDC (no multi-bit crossing).
module c5_native_descriptor(
    input wire clk,input wire rst_n,input wire axi_clk,input wire axi_rst_n,
    input wire [8:0] address,input wire active,input wire [1:0] mode,
    input wire [31:0] generation,input wire [31:0] frame_id,
    input wire frame_done,
    // Read-only diagnostics (clk domain): [95:0] receiver/runtime, [191:96] splitter.
    input wire [191:0] diag,
    input wire [159:0] source_diag_snapshot,
    output reg [31:0] rdata
);
    reg [31:0] published_generation,published_sequence,published_frames;
    function [31:0] geometry_value;
        input [1:0] selected;
        input [31:0] value480;
        input [31:0] value960;
        begin
            geometry_value=selected==2?value480:selected==3?value960:0;
        end
    endfunction
    reg [703:0] source_snapshot;
    reg source_valid;
    wire source_ready;
    wire [703:0] axi_snapshot;
    wire snapshot_valid;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            published_generation<=0;published_sequence<=0;published_frames<=0;
            source_snapshot<=0;source_valid<=0;
        end else begin
            if(source_valid && source_ready)source_valid<=0;
            if(frame_done)begin
                published_generation<=generation;published_sequence<=frame_id;
                published_frames<=published_frames+1'b1;
            end
            if(source_ready)begin
                // Word order (0x20 + 0x10*n): packed{active,mode}, generation,
                // full width, height, half width, bytes per half, half stride
                // in bytes, current frame id, last published gen/seq/count.
                source_snapshot<={source_diag_snapshot,diag,published_frames,published_sequence,published_generation,
                    frame_id,
                    active?geometry_value(mode,1280,1280):0,
                    active?geometry_value(mode,614400,1228800):0,
                    active?geometry_value(mode,640,640):0,
                    active?geometry_value(mode,480,960):0,
                    active?geometry_value(mode,1280,1280):0,
                    generation,{29'd0,active,mode}};
                source_valid<=1;
            end
        end
    end
    c5_serial_snapshot_cdc #(.WIDTH(704)) snapshot_cdc(
        .s_clk(clk),.s_rst_n(rst_n),.s_data(source_snapshot),.s_valid(source_valid),
        .s_ready(source_ready),.d_clk(axi_clk),.d_rst_n(axi_rst_n),
        .d_data(axi_snapshot),.d_valid(snapshot_valid),.d_ready(1'b1));
    // Decode each full address once, then mask/OR the words. This is the same
    // combinational read (including default zero), without a word-index mux
    // tree driven directly by the high-fanout router address bits.
    wire [27:0] read_select;
    wire [31:0] read_word [0:27];
    assign read_select[0]=(address==9'h000);
    assign read_select[1]=(address==9'h010);
    assign read_word[0]=32'h4e484d31;
    assign read_word[1]=32'h00000001;
    genvar slot;
    generate for(slot=0;slot<11;slot=slot+1) begin: geometry_read
        assign read_select[slot+2]=(address==(9'h020+slot*16));
        assign read_word[slot+2]=axi_snapshot[slot*32+:32];
    end endgenerate
    assign read_select[13]=(address==9'h004);
    assign read_select[14]=(address==9'h008);
    assign read_select[15]=(address==9'h00c);
    assign read_select[16]=(address==9'h0d0);
    assign read_select[17]=(address==9'h0e0);
    assign read_select[18]=(address==9'h0f0);
    assign read_select[19]=(address==9'h100);
    assign read_select[20]=(address==9'h110);
    assign read_select[21]=(address==9'h120);
    assign read_select[22]=(address==9'h130);
    assign read_select[23]=(address==9'h140);
    assign read_select[24]=(address==9'h150);
    assign read_select[25]=(address==9'h160);
    assign read_select[26]=(address==9'h170);
    assign read_select[27]=(address==9'h180);
    assign read_word[13]=axi_snapshot[383:352];
    assign read_word[14]=axi_snapshot[415:384];
    assign read_word[15]=axi_snapshot[447:416];
    assign read_word[16]=axi_snapshot[479:448];
    assign read_word[17]=axi_snapshot[511:480];
    assign read_word[18]=axi_snapshot[543:512];
    assign read_word[19]=32'h4e484432;
    assign read_word[20]=axi_snapshot[383:352];
    assign read_word[21]=axi_snapshot[415:384];
    assign read_word[22]=axi_snapshot[447:416];
    assign read_word[23]=axi_snapshot[703:672];
    assign read_word[24]=axi_snapshot[575:544];
    assign read_word[25]=axi_snapshot[607:576];
    assign read_word[26]=axi_snapshot[639:608];
    assign read_word[27]=axi_snapshot[671:640];
    integer word_index;
    always @* begin
        rdata=0;
        for(word_index=0;word_index<28;word_index=word_index+1)
            rdata=rdata | ({32{read_select[word_index]}} & read_word[word_index]);
    end
endmodule
