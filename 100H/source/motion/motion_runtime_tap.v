// Passive motion subsystem and coherent descriptor in the writer AXI clock.
// Source sequence and RAW retired tag have independent origins. Bit1 remains
// clear until a future per-bank association implementation proves alignment.
module motion_runtime_tap #(
    parameter integer WIDTH=640, HEIGHT=480,
    parameter [31:0] TRANSPORT_GEOMETRY=32'h028001e0,
    parameter [31:0] FRAME_BYTES=32'd614400
) (
    input wire clk, rst_n,
    input wire hd_mode, vga_mode, parked,
    input wire [15:0] pixel_rgb565,
    input wire pixel_valid, vsync,
    input wire [31:0] raw_retired_tag,
    input wire [1:0] published_banks,
    output wire [319:0] motion_record,
    output wire [191:0] frame_metadata
);
    // Every input is registered once, so the tap is the previous combinational
    // tap delayed by one clock with all relative timing preserved. Camera
    // VSYNC (fanout ~370) and the runtime-mode/lease decode reached the FIFO
    // overflow logic, epoch and record CE combinationally and failed setup.
    // The tap is passive (its outputs only feed the MMIO motion snapshot).
    reg hd_mode_q, vga_mode_q, parked_q, pixel_valid_q, vsync_q;
    reg [15:0] pixel_rgb565_q;
    reg [31:0] raw_retired_tag_q;
    reg [1:0] published_banks_q;
    always @(posedge clk) begin
        hd_mode_q<=hd_mode; vga_mode_q<=vga_mode; parked_q<=parked;
        pixel_rgb565_q<=pixel_rgb565; pixel_valid_q<=pixel_valid; vsync_q<=vsync;
        raw_retired_tag_q<=raw_retired_tag; published_banks_q<=published_banks;
    end
    wire disabled=hd_mode_q || parked_q;
    wire [319:0] latest;
    reg disabled_q;
    reg [31:0] epoch;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin disabled_q<=0; epoch<=0; end
        else begin
            disabled_q<=disabled;
            if(disabled_q!=disabled) epoch<=epoch+1'b1;
        end
    end
    // Registered disable cuts the lease decode out of async reset fanout.
    // Release may coincide with VSYNC/pixel0: wait for low, then a fresh start.
    // Otherwise a lost pixel plus tolerated trailing dummy can shift history.
    reg motion_armed;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) motion_armed<=0;
        else if(disabled || disabled_q) motion_armed<=0;
        else if(!vsync_q) motion_armed<=1;
    end
    // Detector reset straight from a dedicated register: equals !disabled_q
    // except that it is held low for one extra clock after rst_n release,
    // before motion_armed can admit any pixel. The old rst_n && !disabled_q
    // LUT drove a 400-load reset net and failed setup.
    (* syn_maxfan = 50 *) reg adapter_run;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) adapter_run<=1'b0;
        else adapter_run<=!disabled;
    end
    motion_stream_adapter #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) adapter (
        .clk(clk),.rst_n(adapter_run),.pixel_rgb565(pixel_rgb565_q),
        .pixel_valid(pixel_valid_q && motion_armed),.vsync(vsync_q && motion_armed),.motion_record(latest));
    // Outputs are registered (one clock later than the old combinational
    // values). Their only consumer is the MMIO snapshot capture, which the
    // host reads many clocks after the capture write; the unregistered lease
    // decode -> 6-way snapshot mux path failed setup by 0.6 ns.
    reg [319:0] motion_record_q;
    reg [191:0] frame_metadata_q;
    always @(posedge clk) begin
        motion_record_q<=disabled ? 320'b0 : latest;
        frame_metadata_q<={epoch,30'b0,published_banks_q,
            28'b0,parked_q,hd_mode_q,1'b0,!disabled,
            (hd_mode_q ? 32'd1843200 : (vga_mode_q ? 32'd614400 : FRAME_BYTES)),
            (hd_mode_q ? 32'h050002d0 : (vga_mode_q ? 32'h028001e0 : TRANSPORT_GEOMETRY)),raw_retired_tag_q};
    end
    assign motion_record=motion_record_q;
    assign frame_metadata=frame_metadata_q;
endmodule
