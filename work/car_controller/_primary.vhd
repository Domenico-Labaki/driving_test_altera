library verilog;
use verilog.vl_types.all;
entity car_controller is
    port(
        clk50           : in     vl_logic;
        rst_n           : in     vl_logic;
        tick_60hz       : in     vl_logic;
        game_state      : in     vl_logic_vector(1 downto 0);
        accel           : in     vl_logic;
        brake           : in     vl_logic;
        steer_left      : in     vl_logic;
        steer_right     : in     vl_logic;
        game_active     : in     vl_logic;
        car_x           : out    vl_logic_vector(9 downto 0);
        car_y           : out    vl_logic_vector(9 downto 0);
        car_angle       : out    vl_logic_vector(2 downto 0);
        heading_deg     : out    vl_logic_vector(8 downto 0);
        speed_kph       : out    vl_logic_vector(7 downto 0);
        car_row_bus     : out    vl_logic_vector(307 downto 0)
    );
end car_controller;
