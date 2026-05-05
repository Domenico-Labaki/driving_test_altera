library verilog;
use verilog.vl_types.all;
entity vga_controller is
    port(
        clk50           : in     vl_logic;
        rst_n           : in     vl_logic;
        hsync           : out    vl_logic;
        vsync           : out    vl_logic;
        px              : out    vl_logic_vector(9 downto 0);
        py              : out    vl_logic_vector(9 downto 0);
        active          : out    vl_logic;
        pclk            : out    vl_logic
    );
end vga_controller;
