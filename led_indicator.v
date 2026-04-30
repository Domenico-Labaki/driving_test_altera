// led_indicator.v — LED feedback for game states.
//
// DE2 LEDs:
//   LEDR[17:0] — Red LEDs   (active-high)
//   LEDG[7:0]  — Green LEDs (active-high)
//
// Behavior per game state:
//   IDLE    — all off
//   DRIVING — all green LEDs on, red off
//   FAIL    — red LEDs flash at 4 Hz, green off
//   PASS    — all green LEDs on solid, red off

module led_indicator (
    input  wire        clk50,
    input  wire        rst_n,
    input  wire [1:0]  game_state,  // 0=IDLE 1=DRIVING 2=FAIL 3=PASS
    output reg  [17:0] LEDR,
    output reg  [7:0]  LEDG
);

// ── 4 Hz flash counter for FAIL state ────────────────────────────────────
// 50 MHz / (4 Hz × 2 toggles) = 6,250,000 cycles per half-period
localparam FLASH_HALF = 24'd6_250_000;
reg [23:0] flash_cnt;
reg        flash_bit;

always @(posedge clk50) begin
    if (!rst_n || game_state != 2'd2) begin
        flash_cnt <= 24'd0;
        flash_bit <= 1'b0;
    end else begin
        if (flash_cnt < FLASH_HALF)
            flash_cnt <= flash_cnt + 24'd1;
        else begin
            flash_cnt <= 24'd0;
            flash_bit <= ~flash_bit;
        end
    end
end

// ── LED output mux ─────────────────────────────────────────────────────────
always @(posedge clk50) begin
    if (!rst_n) begin
        LEDR <= 18'd0;
        LEDG <= 8'd0;
    end else begin
        case (game_state)
            2'd0: begin LEDR <= 18'd0; LEDG <= 8'd0; end           // IDLE
            2'd1: begin LEDR <= 18'd0; LEDG <= 8'hFF; end          // DRIVING
            2'd2: begin LEDR <= flash_bit ? 18'h3FFFF : 18'd0;     // FAIL flash
                        LEDG <= 8'd0; end
            2'd3: begin LEDR <= 18'd0; LEDG <= 8'hFF; end          // PASS solid
            default: begin LEDR <= 18'd0; LEDG <= 8'd0; end
        endcase
    end
end

endmodule
