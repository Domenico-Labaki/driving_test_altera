// fsm_game.v — Top-level game state machine.
//
// States:
//   IDLE    — waiting for KEY[3] press
//   DRIVING — car active, collision detection running, timer counting
//   FAIL    — collision occurred; wait for KEY[3] to return to IDLE
//   PASS    — car passed through finish line; wait for KEY[3] to return to IDLE
//
// Finish detection: car center crosses the start/finish line (x == SF_X2)
// while moving in the correct direction (heading northward, angle == 2).

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
    output reg  [15:0] elapsed_sec, // seconds elapsed (for 7-seg)
    output reg  [7:0]  elapsed_ms   // sub-second (hundredths)
);

// ── State encoding ─────────────────────────────────────────────────────────
localparam IDLE    = 2'd0;
localparam DRIVING = 2'd1;
localparam FAIL    = 2'd2;
localparam PASS    = 2'd3;

// ── Timer: counts at 60 Hz ────────────────────────────────────────────────
// 60 ticks = 1 second.  Count up to 65535 seconds.
reg [5:0] tick_cnt;   // counts 0..59

always @(posedge clk50) begin
    if (!rst_n || game_state != DRIVING) begin
        tick_cnt   <= 6'd0;
        elapsed_sec <= 16'd0;
        elapsed_ms  <= 8'd0;
    end else if (tick_60hz && game_state == DRIVING) begin
        if (tick_cnt == 6'd59) begin
            tick_cnt    <= 6'd0;
            elapsed_sec <= elapsed_sec + 16'd1;
            elapsed_ms  <= 8'd0;
        end else begin
            tick_cnt   <= tick_cnt + 6'd1;
            elapsed_ms <= tick_cnt * 8'd166 / 8'd10; // centiseconds approx
        end
    end
end

// ── Finish line detection ─────────────────────────────────────────────────
// Car must cross x == SF_X2 heading north (angle==2) while in DRIVING state.
// We use car_y in [SF_Y1..SF_Y2] to confirm it's in the finish zone.
wire at_finish = (car_x >= `SF_X2 - 10'd2 && car_x <= `SF_X2 + 10'd2) &&
                 (car_y >= `SF_Y1 && car_y <= `SF_Y2) &&
                 (car_angle == 3'd2);  // heading North

// Latch finish crossing on tick
reg finish_prev;
wire finish_pulse;
always @(posedge clk50) begin
    if (!rst_n) finish_prev <= 1'b0;
    else        finish_prev <= at_finish;
end
assign finish_pulse = at_finish & ~finish_prev;  // rising edge

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
                if (collision)     game_state <= FAIL;
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
