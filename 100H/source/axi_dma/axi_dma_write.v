module axi_dma_write
	#(
		parameter WAIT_FOR_DATA = 0, // camera source supplies stored beat credits
		parameter WD_LIMIT = 24'hFFFFFF,
		parameter 		BURST_LEN 	= 8		,
		parameter       ID_WIDTH  	= 4		,
		parameter       DATA_WIDTH 	= 128	,
		parameter       KEEP_WIDTH  = DATA_WIDTH / 8	
	)
	(
	input 				clk 			,    // Clock
	input 				rst 			,
    output wire lease_idle,    // Synchronous reset active high
	
	//cmd interface
	input       	 					cmd_valid		,
	input 			[31:0] 				cmd_addr		,
	input 			[31:0] 				cmd_len			,
	input			[ID_WIDTH - 1:0]    cmd_id          ,
	output reg  	    				cmd_ready		,

	input [15:0] data_in_available, // complete beats already stored upstream
	input abort_req, // sticky source fault, held until retirement
    output reg data_in_abort, // failed command, all AXI obligations retired

	//trans data in
	input 			[DATA_WIDTH - 1:0]  data_in      	,
	input			[KEEP_WIDTH - 1:0]	data_in_keep	,
	input         						data_in_valid	,
	output reg                          data_in_last    ,
	output        						data_in_ready	,

	//axi w
	output reg		[ID_WIDTH - 1:0]   			m_axi_awid   	,
	output reg		[31:0]  					m_axi_awaddr 	,
	output reg		[7:0]   					m_axi_awlen  	,
	output 			[2:0]   					m_axi_awsize 	,
	output 			[1:0]   					m_axi_awburst	,
	output 		    	    					m_axi_awlock 	,
	output 			[3:0]   					m_axi_awcache	,
	output 			[2:0]   					m_axi_awprot	,
	output reg		        					m_axi_awvalid	,
	input  		 	        					m_axi_awready	,
	output 			[DATA_WIDTH - 1:0] 			m_axi_wdata		,
	output 			[KEEP_WIDTH - 1:0]  		m_axi_wstrb		,
	output 			        					m_axi_wlast		,
	output 			        					m_axi_wvalid	,
	input  			        					m_axi_wready	,
	input  			[ID_WIDTH - 1:0]   			m_axi_bid  		,
	input  			[1:0]   					m_axi_bresp 	,
	input  			        					m_axi_bvalid	,
	output 			        					m_axi_bready	

);


localparam AXI_BURST_SIZE = $clog2(KEEP_WIDTH); //log2(DATA_WIDTH / 8)

// [WD 2026-09-18] transmit watchdog state
reg        abort_r;
reg [23:0] wd_cnt;
wire       w_progress;
wire       abort_done;

wire [DATA_WIDTH - 1:0] 		t_m_axi_wdata;	
wire [KEEP_WIDTH - 1:0]  		t_m_axi_wstrb;	
wire         					t_m_axi_wlast;	
wire         					t_m_axi_wvalid;
wire         					t_m_axi_wready;

//common para
assign m_axi_awsize 	= 		AXI_BURST_SIZE	;
assign m_axi_awburst 	= 		2'b01			;
assign m_axi_awlock 	= 		1'b0			;
assign m_axi_awcache 	= 		4'b0011			;
assign m_axi_awprot 	= 		3'b000			;


wire [7:0] burst_len    ;
wire [7:0] max_burst_len;

//cmd
reg [31:0] addr;
reg [31:0] len;
reg        trans;

always @(posedge clk) begin 
	if((cmd_ready == 1'b1) && (cmd_valid == 1'b1))begin
		addr <= cmd_addr;
	end
	else begin
		if((m_axi_awvalid == 1'b1) && (m_axi_awready == 1'b1))begin
			addr <= addr + ((m_axi_awlen + 1'b1) << AXI_BURST_SIZE);
		end
	end
end

always @(posedge clk) begin 
	if(rst == 1'b1)begin
		len <= 32'd0;
	end
	else if((cmd_ready == 1'b1) && (cmd_valid == 1'b1))begin
		len <= cmd_len[31:AXI_BURST_SIZE] + (|cmd_len[AXI_BURST_SIZE - 1:0]);
	end
	else begin
		if((m_axi_awvalid == 1'b1) && (m_axi_awready == 1'b1))begin
			len <= len - (m_axi_awlen + 1'b1);
		end
		else if(abort_done == 1'b1)begin
			len <= 32'd0;       // Discard only unissued remainder after real B.
		end
	end
end
always @(posedge clk)begin
	if(rst == 1'b1)begin
		trans <= 1'b0;
	end
	else begin
		if((cmd_ready == 1'b1) && (cmd_valid == 1'b1))begin
			trans <= 1'b1;
		end
		else begin
			if((m_axi_bready == 1'b1) && (m_axi_bvalid == 1'b1) && (len == 32'd0))begin
				trans <= 1'b0;
			end
			else if(abort_done == 1'b1)begin
				trans <= 1'b0;      // Aborted burst has completed external W and B.
			end
		end
	end
end

always @(posedge  clk)begin
	if(rst == 1'b1)begin
		cmd_ready <= 1'b0;
	end
	else begin
		if(trans == 1'b0)begin
			if((cmd_ready == 1'b1) && (cmd_valid == 1'b1))begin
				cmd_ready <= 1'b0;
			end
			else begin
				cmd_ready <= 1'b1;
			end
		end
		else begin
			cmd_ready <= 1'b0;
		end
	end
end

//aw

reg burst_trans;
assign burst_len     = len > BURST_LEN ? BURST_LEN : len;
// Do not reserve the shared DDR owner while waiting for future pixels.
// Once advertised, AW remains irrevocable even if an abort arrives.
wire source_burst_ready = !WAIT_FOR_DATA ||
                         (data_in_valid && data_in_available >= max_burst_len);
wire waiting_source = WAIT_FOR_DATA && trans && !burst_trans &&
                      !m_axi_awvalid && (len != 0) && !source_burst_ready;
reg [15:0] available_q;
always @(posedge clk) begin
    if(rst) available_q <= 0;
    else available_q <= data_in_available;
end
assign max_burst_len = (((addr & 12'hfff) + (burst_len << AXI_BURST_SIZE )) >> 12)  != 0 ? (13'h1000 - (addr & 12'hfff)) >> AXI_BURST_SIZE : burst_len;
always@(posedge clk)begin
	if(rst == 1'b1)begin
		burst_trans <= 1'b0;
	end
	else begin
		if((m_axi_awvalid == 1'b1) && (m_axi_awready == 1'b1))begin
			burst_trans <= 1'b1;
		end
		else begin
			// if((m_axi_wvalid == 1'b1) && (m_axi_wready == 1'b1) && (m_axi_wlast == 1'b1))begin
			if((m_axi_bvalid == 1'b1) && (m_axi_bready == 1'b1))begin
				burst_trans <= 1'b0;
			end
		end
	end
end
always @(posedge clk)begin
	if(rst == 1'b1)begin
		m_axi_awvalid <= 1'b0;
	end
	else begin
		if((m_axi_awvalid == 1'b1) && (m_axi_awready == 1'b1))begin
			m_axi_awvalid <= 1'b0;
		end
		else begin
			if((trans == 1'b1) && (burst_trans == 1'b0) && (len != 32'd0) && (abort_r == 1'b0) && !abort_req && source_burst_ready)begin
				m_axi_awvalid <= 1'b1;
			end
		end
	end
end

always @(posedge clk)begin
	if(!m_axi_awvalid) m_axi_awlen <= max_burst_len - 8'd1;
end
always @(posedge clk)begin
	if(!m_axi_awvalid) m_axi_awaddr <= addr;
end
always @(posedge clk) begin 
	if((cmd_ready == 1'b1) && (cmd_valid == 1'b1))begin
		m_axi_awid <= cmd_id;
	end
end
//w
reg [7:0] act_burst_len;
always@ (posedge clk)begin
	if(rst == 1'b1)begin
		act_burst_len <= 8'd0;
	end
	else begin
		if((m_axi_awvalid == 1'b1) && (m_axi_awready == 1'b1))begin
			act_burst_len <= m_axi_awlen + 8'd1;
		end
		else begin
			if((t_m_axi_wvalid == 1'b1) && (t_m_axi_wready == 1'b1))begin
				act_burst_len <= act_burst_len - 8'd1;
			end
		end
	end
end

// [WD 2026-09-18] ------------------------------------------------------------------
// The DVP stream can deliver fewer 128-bit beats than CAM_DATA_LEN (CDC FIFO
// overflow drops pixels and cannot back-pressure the sensor). A frame's AXI
// burst then never completes: trans sticks at 1, cmd_ready stays low and the
// frame FSM deadlocks forever (measured: state=ADDR, axi_cnt=0, 0 frames).
//
// Recovery: if there is no W-beat progress for ~0.17 s while a write is in
// flight, close the open burst with dummy beats. AXI forbids cancelling an
// accepted AW, so we must still supply awlen beats; we just no longer consume
// real camera data. After the B response is absorbed, trans/len clear and the
// next frame's command is accepted again (only the bad frame is lost).
assign w_progress = (t_m_axi_wvalid == 1'b1) && (t_m_axi_wready == 1'b1);

// The watchdog follows waiting_source one clock late: the max_burst_len /
// data_in_available compare inside waiting_source drove wd_cnt's reset
// combinationally and failed setup. WD_LIMIT is 2^24-1 clocks, so a one-clock
// shift in when counting starts or stops is immaterial.
reg waiting_source_q;
always @(posedge clk) begin
    if(rst) waiting_source_q <= 1'b0;
    else waiting_source_q <= waiting_source;
end

always @(posedge clk) begin
    if(rst || abort_r) wd_cnt <= 0;
    else if(waiting_source_q) begin
        if(data_in_available != available_q) wd_cnt <= 0;
        else if(wd_cnt != 24'hFFFFFF) wd_cnt <= wd_cnt + 1'b1;
    end
    else if((rst == 1'b1) || (burst_trans == 1'b0) || (abort_r == 1'b1) || (w_progress == 1'b1) || data_in_valid || !t_m_axi_wready)
		wd_cnt <= 24'd0;
	else if(wd_cnt != 24'hFFFFFF)
		wd_cnt <= wd_cnt + 24'd1;
end

// Timeout may fill an accepted burst, but cannot cancel an advertised AW
// or fabricate completion. Waiting AW and waiting B retain their ledger.
always @(posedge clk) begin
    if(rst == 1'b1)
        abort_r <= 1'b0;
    else if(abort_done == 1'b1)
        abort_r <= 1'b0;
    else if(trans && abort_req)
        abort_r <= 1'b1;
    else if(waiting_source && waiting_source_q && (wd_cnt == WD_LIMIT))
        abort_r <= 1'b1; // no AW exists: retire locally without owning DDR
    else if(!abort_r && burst_trans && (act_burst_len != 0)
            && !data_in_valid && t_m_axi_wready && !w_progress && (wd_cnt == WD_LIMIT))
        abort_r <= 1'b1;
end

// BREADY is asserted only after the external final W handshake below.
wire b_fire = m_axi_bvalid && m_axi_bready;
wire failed = abort_r || abort_req || (b_fire && m_axi_bresp[1]);
assign abort_done = trans && failed &&
                    (b_fire || (abort_r && !burst_trans && !m_axi_awvalid));
// ---------------------------------------------------------------------------------

stream_pipe #(
  .DATA_WIDTH 	(DATA_WIDTH+1+KEEP_WIDTH)	
) stream_pipe_3(
  .dataIn_valid     (t_m_axi_wvalid),
  .dataIn_ready     (t_m_axi_wready),
  .dataIn_payload   ({t_m_axi_wdata, t_m_axi_wstrb, t_m_axi_wlast}),
  .dataOut_valid    (m_axi_wvalid),
  .dataOut_ready    (m_axi_wready),
  .dataOut_payload  ({m_axi_wdata, m_axi_wstrb, m_axi_wlast}),
  .clk              (clk),
  .reset            (rst)
);

assign data_in_ready = abort_r ? 1'b0
                               : (t_m_axi_wready && act_burst_len > 8'd0);
assign t_m_axi_wvalid  = abort_r ? (act_burst_len > 8'd0)
                                 : (data_in_valid && act_burst_len > 8'd0);
assign t_m_axi_wdata   = abort_r ? {DATA_WIDTH{1'b0}} : data_in;
assign t_m_axi_wlast   = (act_burst_len == 8'd1);
assign t_m_axi_wstrb   = abort_r ? {KEEP_WIDTH{1'b0}} : data_in_keep;

//b
reg w_done;
always @(posedge clk) begin
	if(rst == 1'b1) begin
		w_done <= 1'b0;
	end
	else begin
		if((m_axi_wvalid == 1'b1) && (m_axi_wready == 1'b1) && (m_axi_wlast == 1'b1)) begin
			w_done <= 1'b1;
		end
		else begin
			if((m_axi_bvalid == 1'b1) && (m_axi_bready == 1'b1)) begin
				w_done <= 1'b0;
			end
		end
	end
end
assign m_axi_bready = w_done;
// Explicit retirement predicate includes queued/accepted AW, stream W and B.
assign lease_idle = cmd_ready && !trans && !burst_trans && !m_axi_awvalid &&
                    !m_axi_wvalid && !w_done && !data_in_abort && !data_in_last;

// Success and failure are mutually exclusive and follow real external B.
always @(posedge clk) begin
    if(rst) begin
        data_in_last <= 1'b0;
        data_in_abort <= 1'b0;
    end else begin
        data_in_last <= trans && b_fire && (len == 0) && !failed;
        data_in_abort <= abort_done;
    end
end

endmodule
