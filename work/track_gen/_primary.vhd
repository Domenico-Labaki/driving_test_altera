library verilog;
use verilog.vl_types.all;
entity track_gen is
    port(
        clk50           : in     vl_logic;
        rst_n           : in     vl_logic;
        seg_bus         : out    vl_logic_vector(479 downto 0);
        num_segs        : out    vl_logic_vector(3 downto 0);
        cone_bus        : out    vl_logic_vector(159 downto 0);
        num_cones       : out    vl_logic_vector(3 downto 0);
        bldg_bus        : out    vl_logic_vector(215 downto 0);
        num_bldgs       : out    vl_logic_vector(3 downto 0);
        coin_bus        : out    vl_logic_vector(239 downto 0);
        num_coins       : out    vl_logic_vector(3 downto 0)
    );
end track_gen;
