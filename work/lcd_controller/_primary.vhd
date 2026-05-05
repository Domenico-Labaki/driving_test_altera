library verilog;
use verilog.vl_types.all;
entity lcd_controller is
    port(
        clk50           : in     vl_logic;
        rst_n           : in     vl_logic;
        game_state      : in     vl_logic_vector(1 downto 0);
        LCD_EN          : out    vl_logic;
        LCD_RS          : out    vl_logic;
        LCD_RW          : out    vl_logic;
        LCD_DATA        : out    vl_logic_vector(7 downto 0)
    );
end lcd_controller;
