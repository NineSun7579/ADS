module find_one(
        input       [6'd63:0]  i_din,
        output      [3'd5:0]   o_index
    );
wire    [5'd31:0]   tmp4;
wire    [4'd15:0]   tmp3;
wire    [3'd7:0]   tmp0;
wire    [2'd3:0]   tmp1;
wire    [1'd1:0]   tmp2;
assign o_index[3'd5] = (|i_din[6'd63:6'd32]);
assign tmp4 = o_index[3'd5] ? i_din[6'd63:6'd32] : i_din[5'd31:1'd0];

assign o_index[3'd4] = (|tmp4[5'd31:5'd16]);
assign tmp3 = o_index[3'd4] ? tmp4[5'd31:5'd16] : tmp4[4'd15:1'd0];

assign o_index[2'd3] = (|tmp3[4'd15:4'd8]);
assign tmp0 = o_index[2'd3] ? tmp3[4'd15:4'd8] : tmp3[3'd7:1'd0];

assign o_index[2'd2] = (|tmp0[3'd7:3'd4]);
assign tmp1 = o_index[2'd2] ? tmp0[3'd7:3'd4] : tmp0[2'd3:1'd0];

assign o_index[1'd1] = (|tmp1[2'd3:2'd2]);
assign tmp2 = o_index[1'd1] ? tmp1[2'd3:2'd2] : tmp1[1'b1:1'b0];

assign o_index[1'b0] = tmp2[1'b1];

endmodule