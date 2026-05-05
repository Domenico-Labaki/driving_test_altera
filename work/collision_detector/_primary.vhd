library verilog;
use verilog.vl_types.all;
entity collision_detector is
    port(
        clk50           : in     vl_logic;
        rst_n           : in     vl_logic;
        tick_60hz       : in     vl_logic;
        car_x           : in     vl_logic_vector(9 downto 0);
        car_y           : in     vl_logic_vector(9 downto 0);
        corner_offroad  : in     vl_logic_vector(3 downto 0);
        cone_bus        : in     vl_logic_vector(159 downto 0);
        num_cones       : in     vl_logic_vector(3 downto 0);
        collision       : out    vl_logic
    );
end collision_detector;
