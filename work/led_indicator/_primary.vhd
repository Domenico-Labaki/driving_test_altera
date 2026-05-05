library verilog;
use verilog.vl_types.all;
entity led_indicator is
    port(
        clk50           : in     vl_logic;
        rst_n           : in     vl_logic;
        game_state      : in     vl_logic_vector(1 downto 0);
        LEDR            : out    vl_logic_vector(17 downto 0);
        LEDG            : out    vl_logic_vector(7 downto 0)
    );
end led_indicator;
