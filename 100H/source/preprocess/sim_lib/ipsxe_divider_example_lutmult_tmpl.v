// Created by IP Generator (Version 2022.2 build 117120)
// Instantiation Template
//
// Insert the following codes into your Verilog file.
//   * Change the_instance_name to your own instance name.
//   * Change the signal names in the port associations


example_lutmult the_instance_name (
  .aclk(aclk),                                        // input
  .s_axis_dividend_tdata(s_axis_dividend_tdata),      // input
  .s_axis_dividend_tvalid(s_axis_dividend_tvalid),    // input
  .s_axis_dividend_tready(s_axis_dividend_tready),    // output
  .s_axis_divisor_tdata(s_axis_divisor_tdata),        // input
  .s_axis_divisor_tvalid(s_axis_divisor_tvalid),      // input
  .s_axis_divisor_tlast(s_axis_divisor_tlast),        // input
  .s_axis_divisor_tready(s_axis_divisor_tready),      // output
  .m_axis_dout_tvalid(m_axis_dout_tvalid),            // output
  .m_axis_dout_tdata(m_axis_dout_tdata),              // output
  .m_axis_dout_tlast(m_axis_dout_tlast)               // output
);
