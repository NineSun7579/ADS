-- Created by IP Generator (Version 2022.2 build 117120)
-- Instantiation Template
--
-- Insert the following codes into your VHDL file.
--   * Change the_instance_name to your own instance name.
--   * Change the net names in the port map.


COMPONENT example_lutmult
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_dividend_tdata : IN STD_LOGIC;
    s_axis_dividend_tvalid : IN STD_LOGIC;
    s_axis_dividend_tready : OUT STD_LOGIC;
    s_axis_divisor_tdata : IN STD_LOGIC;
    s_axis_divisor_tvalid : IN STD_LOGIC;
    s_axis_divisor_tlast : IN STD_LOGIC;
    s_axis_divisor_tready : OUT STD_LOGIC;
    m_axis_dout_tvalid : OUT STD_LOGIC;
    m_axis_dout_tdata : OUT STD_LOGIC;
    m_axis_dout_tlast : OUT STD_LOGIC
  );
END COMPONENT;


the_instance_name : example_lutmult
  PORT MAP (
    aclk => aclk,
    s_axis_dividend_tdata => s_axis_dividend_tdata,
    s_axis_dividend_tvalid => s_axis_dividend_tvalid,
    s_axis_dividend_tready => s_axis_dividend_tready,
    s_axis_divisor_tdata => s_axis_divisor_tdata,
    s_axis_divisor_tvalid => s_axis_divisor_tvalid,
    s_axis_divisor_tlast => s_axis_divisor_tlast,
    s_axis_divisor_tready => s_axis_divisor_tready,
    m_axis_dout_tvalid => m_axis_dout_tvalid,
    m_axis_dout_tdata => m_axis_dout_tdata,
    m_axis_dout_tlast => m_axis_dout_tlast
  );
