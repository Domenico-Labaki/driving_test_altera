// fsm_game.v — Top-level game state machine.
//
// States:
//   IDLE    — waiting for KEY[3] press
//   DRIVING — car active, collision detection running, timer counting
//   FAIL    — collision occurred; wait for KEY[3] to return to IDLE
//   PASS    — car passed through finish line; wait for KEY[3] to return to IDLE
//
// Finish detection: car center crosses FINISH_LINE_Y while heading north.

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
    // Outputs
    output reg  [1:0]  game_state,  // 0=IDLE 1=DRIVING 2=FAIL 3=PASS
    output reg         game_active, // DRIVING state
    output reg  [15:0] remaining_sec, // countdown seconds (for 7-seg)
    output reg  [7:0]  remaining_ms   // centiseconds approximation
);

// ── State encoding ─────────────────────────────────────────────────────────
localparam IDLE    = 2'd0;
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
    end else if (game_state == IDLE) begin
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

// ── Finish line detection ─────────────────────────────────────────────────
// Car crosses FINISH_LINE_Y heading north (heading_deg ~225..315, car_angle 5 or 6).
// A "has_left_start" flag prevents triggering before the car has moved away.
reg has_left_start;
always @(posedge clk50) begin
    if (!rst_n || game_state == IDLE)
        has_left_start <= 1'b0;
    else if (game_state == DRIVING && car_y < (`FINISH_LINE_Y + 10'd50))
        has_left_start <= 1'b1;  // car has travelled well past start
end

wire at_finish = has_left_start &&
                 (car_y >= (`FINISH_LINE_Y - 10'd3) && car_y <= (`FINISH_LINE_Y + 10'd3)) &&
                 (car_x >= `FINISH_LINE_X1 && car_x <= `FINISH_LINE_X2) &&
                 (car_angle == 3'd5 || car_angle == 3'd6);  // heading north-ish (225..315 deg)

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
        game_state  <= IDLE;
        game_active <= 1'b0;
    end else begin
        case (game_state)
            IDLE: begin
                game_active <= 1'b0;
                if (start_btn) game_state <= DRIVING;
            end
            DRIVING: begin
                game_active <= 1'b1;
                if (collision || time_up) game_state <= FAIL;
                else if (finish_pulse) game_state <= PASS;
            end
            FAIL: begin
                game_active <= 1'b0;
                if (start_btn) game_state <= IDLE;
            end
            PASS: begin
                game_active <= 1'b0;
                if (start_btn) game_state <= IDLE;
            end
            default: game_state <= IDLE;
        endcase
    end
end

endmodule