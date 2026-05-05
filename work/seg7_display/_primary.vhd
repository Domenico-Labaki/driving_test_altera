library verilog;
use verilog.vl_types.all;
entity seg7_display is
    port(
        clk50           : in     vl_logic;
        rst_n           : in     vl_logic;
        remaining_sec   : in     vl_logic_vector(15 downto 0);
        remaining_ms    : in     vl_logic_vector(7 downto 0);
        speed_kph       : in     vl_logic_vector(7 downto 0);
        coin_count      : in     vl_logic_vector(3 downto 0);
        HEX0            : out    vl_logic_vector(6 downto 0);
        HEX1            : out    vl_logic_vector(6 downto 0);
        HEX2            : out    vl_logic_vector(6 downto 0);
        HEX3            : out    vl_logic_vector(6 downto 0);
        HEX4            : out    vl_logic_vector(6 downto 0);
        HEX5            : out    vl_logic_vector(6 downto 0);
        HEX6            : out    vl_logic_vector(6 downto 0);
        HEX7            : out    vl_logic_vector(6 downto 0)
    );
end seg7_display;
