// fsm_game.v — Top-level game state machine.
//
// States:
//   MENU    — waiting for KEY[3] press
//   DRIVING — car active, collision detection running, timer counting
//   FAIL    — collision occurred; wait for KEY[3] to return to MENU
//   PASS    — car passed through finish line; wait for KEY[3] to return to MENU
//
// Finish detection: car must stop completely inside parking rectangle with all coins collected.

`include "track_data.vh"

module fsm_game (
    input  wire        clk50,
    input  wire        rst_n,
    input  wire        tick_60hz,
    // Inputs
    input  wire        start_btn,    // KEY[3] debounced pulse
    input  wire        collision,    // from collision_detector
    input  wire [9:0]  car_x,
    input  wire [9:0]  car_y,
    input  wire [2:0]  car_angle,
    input  wire [7:0]  speed_kph,   // car speed (0 when stopped)
    input  wire [3:0]  coin_count,  // coins collected
    input  wire [3:0]  num_coins,   // total coins in level
    // Outputs
    output reg  [1:0]  game_state,  // 0=MENU 1=DRIVING 2=FAIL 3=PASS
    output reg         game_active, // DRIVING state
    output reg  [15:0] remaining_sec, // countdown seconds (for 7-seg)
    output reg  [7:0]  remaining_ms   // centiseconds approximation
);

// ── State encoding ─────────────────────────────────────────────────────────
localparam MENU    = 2'd0;
localparam DRIVING = 2'd1;
localparam FAIL    = 2'd2;
localparam PASS    = 2'd3;

// ── Timer: counts at 60 Hz ────────────────────────────────────────────────
// 60 ticks = 1 second. Countdown starts at 60 seconds.
localparam [15:0] ROUND_TIME_SEC = 16'd60;
reg [5:0] tick_cnt;   // counts 0..59

always @(posedge clk50) begin
    if (!rst_n) begin
        tick_cnt      <= 6'd0;
        remaining_sec <= ROUND_TIME_SEC;
        remaining_ms  <= 8'd0;
    end else if (game_state == MENU) begin
        tick_cnt   <= 6'd0;
        remaining_sec <= ROUND_TIME_SEC;
        remaining_ms  <= 8'd0;
    end else if (tick_60hz && game_state == DRIVING) begin
        if (tick_cnt == 6'd59) begin
            tick_cnt    <= 6'd0;
            if (remaining_sec != 16'd0)
                remaining_sec <= remaining_sec - 16'd1;
            remaining_ms <= 8'd0;
        end else begin
            tick_cnt   <= tick_cnt + 6'd1;
            remaining_ms <= ((6'd59 - tick_cnt) * 8'd100) / 8'd60;
        end
    end
end

// ── Finish line detection (parking space requirement) ──────────────────────
// Car must:
//   1. Be effectively stopped (displayed speed near 0)
//   2. Have the entire sprite bounding box inside the parking rectangle
//   3. Have collected all coins (coin_count == num_coins)
//   4. Be heading north-ish (car_angle 5 or 6)
// A "has_left_start" flag prevents triggering before the car has moved away.
reg has_left_start;
always @(posedge clk50) begin
    if (!rst_n || game_state == MENU)
        has_left_start <= 1'b0;
    else if (game_state == DRIVING && car_x < (`PARKING_X2 + 10'd50))
        has_left_start <= 1'b1;  // car has travelled towards parking zone
end

wire all_coins_collected = (num_coins > 4'd0) && (coin_count == num_coins);
// Sprite extents:
//  - horizontal: car occupies car_x - 7 .. car_x + 6  (14 pixels)
//  - vertical:   car occupies car_y - 5 .. car_y + 5  (11 pixels)
// Require the whole sprite bounding box to be inside the parking rectangle.
wire stopped = (speed_kph <= 8'd2);

wire at_finish = has_left_start &&
                 (car_x >= (`PARKING_X1 + 10'd7) && car_x <= (`PARKING_X2 - 10'd6)) &&
                 (car_y >= (`PARKING_Y1 + 10'd5) && car_y <= (`PARKING_Y2 - 10'd5)) &&
                 stopped &&
                 all_coins_collected &&
                 (car_angle == 3'd5 || car_angle == 3'd6);  // heading north

// Latch finish crossing on tick
reg finish_prev;
wire finish_pulse;
always @(posedge clk50) begin
    if (!rst_n) finish_prev <= 1'b0;
    else        finish_prev <= at_finish;
end
assign finish_pulse = at_finish & ~finish_prev;  // rising edge
wire time_up = (remaining_sec == 16'd0);

// ── FSM ───────────────────────────────────────────────────────────────────
always @(posedge clk50) begin
    if (!rst_n) begin
        game_state  <= MENU;
        game_active <= 1'b0;
    end else begin
        case (game_state)
            MENU: begin
                game_active <= 1'b0;
                if (start_btn) game_state <= DRIVING;
            end
            DRIVING: begin
                game_active <= 1'b1;
                if (start_btn) game_state <= MENU;
                else if (collision || time_up) game_state <= FAIL;
                else if (finish_pulse) game_state <= PASS;
            end
            FAIL: begin
                game_active <= 1'b0;
                if (start_btn) game_state <= MENU;
            end
            PASS: begin
                game_active <= 1'b0;
                if (start_btn) game_state <= MENU;
            end
            default: game_state <= MENU;
        endcase
    end
end

endmodule