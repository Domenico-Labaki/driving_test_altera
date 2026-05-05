library verilog;
use verilog.vl_types.all;
entity driving_test_top is
    port(
        CLOCK_50        : in     vl_logic;
        KEY             : in     vl_logic_vector(3 downto 0);
        SW              : in     vl_logic_vector(1 downto 0);
        VGA_R           : out    vl_logic_vector(9 downto 0);
        VGA_G           : out    vl_logic_vector(9 downto 0);
        VGA_B           : out    vl_logic_vector(9 downto 0);
        VGA_HS          : out    vl_logic;
        VGA_VS          : out    vl_logic;
        VGA_BLANK       : out    vl_logic;
        VGA_SYNC        : out    vl_logic;
        VGA_CLK         : out    vl_logic;
        LCD_EN          : out    vl_logic;
        LCD_RS          : out    vl_logic;
        LCD_RW          : out    vl_logic;
        LCD_DATA        : out    vl_logic_vector(7 downto 0);
        LCD_ON          : out    vl_logic;
        LCD_BLON        : out    vl_logic;
        HEX0            : out    vl_logic_vector(6 downto 0);
        HEX1            : out    vl_logic_vector(6 downto 0);
        HEX2            : out    vl_logic_vector(6 downto 0);
        HEX3            : out    vl_logic_vector(6 downto 0);
        HEX4            : out    vl_logic_vector(6 downto 0);
        HEX5            : out    vl_logic_vector(6 downto 0);
        HEX6            : out    vl_logic_vector(6 downto 0);
        HEX7            : out    vl_logic_vector(6 downto 0);
        LEDR            : out    vl_logic_vector(17 downto 0);
        LEDG            : out    vl_logic_vector(7 downto 0);
        GPIO_0_0        : out    vl_logic
    );
end driving_test_top;
