library verilog;
use verilog.vl_types.all;
entity coin_collector is
    port(
        clk50           : in     vl_logic;
        rst_n           : in     vl_logic;
        tick_60hz       : in     vl_logic;
        game_active     : in     vl_logic;
        car_x           : in     vl_logic_vector(9 downto 0);
        car_y           : in     vl_logic_vector(9 downto 0);
        coin_bus        : in     vl_logic_vector(239 downto 0);
        num_coins       : in     vl_logic_vector(3 downto 0);
        collected       : out    vl_logic_vector(11 downto 0);
        coin_count      : out    vl_logic_vector(3 downto 0)
    );
end coin_collector;
