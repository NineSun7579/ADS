// Three video-frontends share one exact iterative 64/64 divider. The selected
// channel is locked until its result returns; requests use round-robin order.
module lane_divider_shared_iterative (
    input  wire         clk,
    input  wire         rst_n,
    input  wire [2:0]   req_valid,
    output wire [2:0]   req_ready,
    input  wire [191:0] req_dividend,
    input  wire [191:0] req_divisor,
    output wire [2:0]   rsp_valid,
    output wire [127:0] rsp_data
);
    reg active;
    reg [1:0] owner;
    reg [1:0] turn;
    wire [1:0] select = active ? owner :
                        req_valid[turn] ? turn :
                        req_valid[turn == 2'd2 ? 2'd0 : turn + 1'b1] ?
                            (turn == 2'd2 ? 2'd0 : turn + 1'b1) :
                        req_valid[turn == 2'd0 ? 2'd2 : turn - 1'b1] ?
                            (turn == 2'd0 ? 2'd2 : turn - 1'b1) : turn;
    wire select_valid = !active && |req_valid;
    wire [63:0] select_dividend = select == 2'd0 ? req_dividend[63:0] :
                                  select == 2'd1 ? req_dividend[127:64] : req_dividend[191:128];
    wire [63:0] select_divisor = select == 2'd0 ? req_divisor[63:0] :
                                 select == 2'd1 ? req_divisor[127:64] : req_divisor[191:128];
    wire dividend_ready, result_valid;
    wire accept = select_valid && dividend_ready;

    assign req_ready[0] = select_valid && select == 2'd0 && req_valid[0] && dividend_ready;
    assign req_ready[1] = select_valid && select == 2'd1 && req_valid[1] && dividend_ready;
    assign req_ready[2] = select_valid && select == 2'd2 && req_valid[2] && dividend_ready;
    assign rsp_valid[0] = active && owner == 2'd0 && result_valid;
    assign rsp_valid[1] = active && owner == 2'd1 && result_valid;
    assign rsp_valid[2] = active && owner == 2'd2 && result_valid;

    lane_divider_iterative u_divider (
        .clk(clk), .rst_n(rst_n),
        .dividend(select_dividend), .divisor(select_divisor),
        .start(select_valid), .ready(dividend_ready), .done(result_valid),
        .quotient(rsp_data[127:64]), .remainder(rsp_data[63:0])
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active <= 1'b0;
            owner <= 2'd0;
            turn <= 2'd0;
        end else begin
            if (accept) begin
                active <= 1'b1;
                owner <= select;
                turn <= select == 2'd2 ? 2'd0 : select + 1'b1;
            end else if (active && result_valid) begin
                active <= 1'b0;
            end
        end
    end
endmodule
