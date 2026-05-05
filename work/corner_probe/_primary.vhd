library verilog;
use verilog.vl_types.all;
entity corner_probe is
    port(
        px              : in     vl_logic_vector(9 downto 0);
        py              : in     vl_logic_vector(9 downto 0);
        seg_bus         : in     vl_logic_vector(479 downto 0);
        num_segs        : in     vl_logic_vector(3 downto 0);
        offroad         : out    vl_logic
    );
end corner_probe;
