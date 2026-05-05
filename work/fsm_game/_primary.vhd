library verilog;
use verilog.vl_types.all;
entity fsm_game is
    port(
        clk50           : in     vl_logic;
        rst_n           : in     vl_logic;
        tick_60hz       : in     vl_logic;
        start_btn       : in     vl_logic;
        collision       : in     vl_logic;
        car_x           : in     vl_logic_vector(9 downto 0);
        car_y           : in     vl_logic_vector(9 downto 0);
        car_angle       : in     vl_logic_vector(2 downto 0);
        speed_kph       : in     vl_logic_vector(7 downto 0);
        coin_count      : in     vl_logic_vector(3 downto 0);
        num_coins       : in     vl_logic_vector(3 downto 0);
        game_state      : out    vl_logic_vector(1 downto 0);
        game_active     : out    vl_logic;
        remaining_sec   : out    vl_logic_vector(15 downto 0);
        remaining_ms    : out    vl_logic_vector(7 downto 0)
    );
end fsm_game;
