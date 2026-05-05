// driving_test_top.v — Top-level wiring for GEL372 FPGA Driving Test.
//
// Target: Altera DE2 — EP2C35F672C6
// Tool:   Intel Quartus Prime
//
// Added: coin_collector, coin buses passed to renderer and seg7.

`include "track_data.vh"

module driving_test_top (
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,
    input  wire [1:0]  SW,
    // VGA
    output wire [9:0]  VGA_R, VGA_G, VGA_B,
    output wire        VGA_HS, VGA_VS, VGA_BLANK, VGA_SYNC, VGA_CLK,
    // LCD
    output wire        LCD_EN, LCD_RS, LCD_RW,
    output wire [7:0]  LCD_DATA,
    output wire        LCD_ON, LCD_BLON,
    // Seven-segment
    output wire [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7,
    // LEDs
    output wire [17:0] LEDR,
    output wire [7:0]  LEDG,
    // Audio buzzer
    output wire        GPIO_0_0
);

wire rst_n = KEY[2];

// ── VGA ───────────────────────────────────────────────────────────────────
wire pclk, active, hsync, vsync;
wire [9:0] px, py;

vga_controller u_vga (
    .clk50(CLOCK_50), .rst_n(rst_n),
    .hsync(hsync), .vsync(vsync),
    .px(px), .py(py), .active(active), .pclk(pclk)
);

assign VGA_HS    = hsync;
assign VGA_VS    = vsync;
assign VGA_SYNC  = 1'b0;
assign VGA_BLANK = active;
assign VGA_CLK   = pclk;

// ── 60 Hz tick ───────────────────────────────────────────────────────────
reg vsync_d;
always @(posedge CLOCK_50) begin
    if (!rst_n) vsync_d <= 1'b1;
    else        vsync_d <= vsync;
end
wire tick_60hz = vsync_d & ~vsync;

// ── Input handler ─────────────────────────────────────────────────────────
wire accel, brake, steer_left, steer_right, start_btn;

input_handler u_input (
    .clk50(CLOCK_50), .rst_n(rst_n),
    .sw(SW[1:0]), .key(KEY),
    .accel(accel), .brake(brake),
    .steer_left(steer_left), .steer_right(steer_right),
    .start_btn(start_btn)
);

// ── Procedural track generator ────────────────────────────────────────────
wire [(`MAX_SEGS*40)-1:0]  seg_bus;
wire [3:0]                  num_segs;
wire [(`MAX_CONES*20)-1:0]  cone_bus;
wire [3:0]                  num_cones;
wire [(`MAX_BLDGS*36)-1:0]  bldg_bus;
wire [3:0]                  num_bldgs;
wire [(`MAX_COINS*20)-1:0]  coin_bus;
wire [3:0]                  num_coins;
wire                        placement_valid;

track_gen u_tgen (
    .clk50(CLOCK_50), .rst_n(rst_n),
    .reload(start_btn),
    .seg_bus(seg_bus),   .num_segs(num_segs),
    .cone_bus(cone_bus), .num_cones(num_cones),
    .bldg_bus(bldg_bus), .num_bldgs(num_bldgs),
    .coin_bus(coin_bus), .num_coins(num_coins),
    .placement_valid(placement_valid)
);

// ── Car controller ────────────────────────────────────────────────────────
wire [9:0]   car_x, car_y;
wire [2:0]   car_angle;
wire [8:0]   heading_deg;
wire [7:0]   speed_kph;
wire [307:0] car_row_bus;
wire         game_active;

car_controller u_car (
    .clk50(CLOCK_50), .rst_n(rst_n),
    .tick_60hz(tick_60hz),
    .game_state(game_state),
    .accel(accel), .brake(brake),
    .steer_left(steer_left), .steer_right(steer_right),
    .car_x(car_x), .car_y(car_y),
    .car_angle(car_angle), .heading_deg(heading_deg),
    .speed_kph(speed_kph),
    .car_row_bus(car_row_bus)
);

// ── Coin collector ────────────────────────────────────────────────────────
wire [`MAX_COINS-1:0] collected;
wire [3:0]            coin_count;

coin_collector u_coins (
    .clk50(CLOCK_50), .rst_n(rst_n),
    .tick_60hz(tick_60hz),
    .game_active(game_active),
    .car_x(car_x), .car_y(car_y),
    .coin_bus(coin_bus), .num_coins(num_coins),
    .collected(collected),
    .coin_count(coin_count)
);

// ── Collision detection ───────────────────────────────────────────────────
wire [3:0] corner_offroad;

corner_probe u_c0 (.px(car_x-10'd7), .py(car_y-10'd5),
                   .seg_bus(seg_bus), .num_segs(num_segs), .offroad(corner_offroad[0]));
corner_probe u_c1 (.px(car_x+10'd6), .py(car_y-10'd5),
                   .seg_bus(seg_bus), .num_segs(num_segs), .offroad(corner_offroad[1]));
corner_probe u_c2 (.px(car_x-10'd7), .py(car_y+10'd5),
                   .seg_bus(seg_bus), .num_segs(num_segs), .offroad(corner_offroad[2]));
corner_probe u_c3 (.px(car_x+10'd6), .py(car_y+10'd5),
                   .seg_bus(seg_bus), .num_segs(num_segs), .offroad(corner_offroad[3]));

wire collision;

collision_detector u_col (
    .clk50(CLOCK_50), .rst_n(rst_n),
    .tick_60hz(tick_60hz),
    .car_x(car_x), .car_y(car_y),
    .corner_offroad(corner_offroad),
    .cone_bus(cone_bus), .num_cones(num_cones),
    .collision(collision)
);

// ── Game FSM ──────────────────────────────────────────────────────────────
wire [1:0]  game_state;
wire [15:0] remaining_sec;

fsm_game u_fsm (
    .clk50(CLOCK_50), .rst_n(rst_n),
    .tick_60hz(tick_60hz),
    .start_btn(start_btn), .collision(collision),
    .car_x(car_x), .car_y(car_y), .car_angle(car_angle),
    .speed_kph(speed_kph), .coin_count(coin_count), .num_coins(num_coins),
    .game_state(game_state), .game_active(game_active),
    .remaining_sec(remaining_sec)
);

// ── Track renderer ────────────────────────────────────────────────────────
wire [23:0] rgb;

track_renderer u_render (
    .pclk(pclk), .rst_n(rst_n), .active(active),
    .px(px), .py(py), .game_state(game_state),
    .car_x(car_x), .car_y(car_y),
    .heading_deg(heading_deg),
    .car_row_bus(car_row_bus),
    .seg_bus(seg_bus),   .num_segs(num_segs),
    .cone_bus(cone_bus), .num_cones(num_cones),
    .bldg_bus(bldg_bus), .num_bldgs(num_bldgs),
    .coin_bus(coin_bus), .num_coins(num_coins),
    .collected(collected),
    .rgb(rgb)
);

assign VGA_R = {rgb[23:16], 2'b00};
assign VGA_G = {rgb[15:8],  2'b00};
assign VGA_B = {rgb[7:0],   2'b00};

// ── LCD ───────────────────────────────────────────────────────────────────
lcd_controller u_lcd (
    .clk50(CLOCK_50), .rst_n(rst_n),
    .game_state(game_state),
    .LCD_EN(LCD_EN), .LCD_RS(LCD_RS), .LCD_RW(LCD_RW), .LCD_DATA(LCD_DATA)
);

// Tie LCD power and backlight on (required for display to show)
assign LCD_ON   = 1'b1;
assign LCD_BLON = 1'b1;

// ── Seven-segment (coin count on HEX7:HEX6) ──────────────────────────────
seg7_display u_seg7 (
    .clk50(CLOCK_50), .rst_n(rst_n),
    .remaining_sec(remaining_sec),
    .speed_kph(speed_kph),
    .coin_count(coin_count),
    .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2),
    .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5), .HEX6(HEX6), .HEX7(HEX7)
);

// ── LEDs / Audio ──────────────────────────────────────────────────────────
wire [17:0] ledr_fsm;
wire [7:0]  ledg_fsm;

led_indicator u_leds (
    .clk50(CLOCK_50), .rst_n(rst_n),
    .game_state(game_state),
    .LEDR(ledr_fsm), .LEDG(ledg_fsm)
);

assign LEDR = ledr_fsm;
assign LEDG = ledg_fsm;

audio_controller u_audio (
    .clk50(CLOCK_50), .rst_n(rst_n),
    .game_state(game_state),
    .buzzer_out(GPIO_0_0)
);

endmodule

// ── corner_probe ──────────────────────────────────────────────────────────
`include "track_data.vh"

module corner_probe (
    input  wire [9:0] px, py,
    input  wire [(`MAX_SEGS*40)-1:0] seg_bus,
    input  wire [3:0]                num_segs,
    output wire       offroad
);

function [0:0] is_on_track_cp;
    input [9:0] fpx, fpy;
    input [(`MAX_SEGS*40)-1:0] sbus;
    input [3:0] nseg;
    integer i;
    reg [9:0] sx1,sy1,sx2,sy2;
    begin
        is_on_track_cp = 1'b0;
        for (i = 0; i < `MAX_SEGS; i = i + 1) begin
            if (i < nseg) begin
                sx1=sbus[i*40+39 -: 10]; sy1=sbus[i*40+29 -: 10];
                sx2=sbus[i*40+19 -: 10]; sy2=sbus[i*40+ 9 -: 10];
                if (fpx>=sx1 && fpx<=sx2 && fpy>=sy1 && fpy<=sy2)
                    is_on_track_cp = 1'b1;
            end
        end
    end
endfunction

assign offroad = ~is_on_track_cp(px, py, seg_bus, num_segs);

endmodule