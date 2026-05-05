library verilog;
use verilog.vl_types.all;
entity track_renderer is
    port(
        pclk            : in     vl_logic;
        rst_n           : in     vl_logic;
        active          : in     vl_logic;
        px              : in     vl_logic_vector(9 downto 0);
        py              : in     vl_logic_vector(9 downto 0);
        car_x           : in     vl_logic_vector(9 downto 0);
        car_y           : in     vl_logic_vector(9 downto 0);
        car_angle       : in     vl_logic_vector(2 downto 0);
        heading_deg     : in     vl_logic_vector(8 downto 0);
        car_row_bus     : in     vl_logic_vector(307 downto 0);
        seg_bus         : in     vl_logic_vector(479 downto 0);
        num_segs        : in     vl_logic_vector(3 downto 0);
        cone_bus        : in     vl_logic_vector(159 downto 0);
        num_cones       : in     vl_logic_vector(3 downto 0);
        bldg_bus        : in     vl_logic_vector(215 downto 0);
        num_bldgs       : in     vl_logic_vector(3 downto 0);
        coin_bus        : in     vl_logic_vector(239 downto 0);
        num_coins       : in     vl_logic_vector(3 downto 0);
        collected       : in     vl_logic_vector(11 downto 0);
        rgb             : out    vl_logic_vector(23 downto 0)
    );
end track_renderer;
