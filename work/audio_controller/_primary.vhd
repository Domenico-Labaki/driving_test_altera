library verilog;
use verilog.vl_types.all;
entity audio_controller is
    port(
        clk50           : in     vl_logic;
        rst_n           : in     vl_logic;
        game_state      : in     vl_logic_vector(1 downto 0);
        buzzer_out      : out    vl_logic
    );
end audio_controller;
