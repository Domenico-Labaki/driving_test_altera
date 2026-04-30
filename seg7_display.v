// seg7_display.v — Seven-segment display driver.
//
// Displays:
//   HEX5:HEX4 — remaining time SS (countdown)
//   HEX3:HEX2 — speed in kph  (0–99)
//   HEX1:HEX0 — unused / all off
//
// DE2 seven-segment segments are active-low.
// Segment map (standard):  gfedcba  (bit 6 = g, bit 0 = a)

module seg7_display (
    input  wire        clk50,
    input  wire        rst_n,
    input  wire [15:0] remaining_sec, // seconds countdown from FSM
    input  wire [7:0]  remaining_ms,  // centiseconds (unused for now)
    input  wire [7:0]  speed_kph,    // 0–99
    // DE2 seven-segment outputs (active-low)
    output reg  [6:0]  HEX0,
    output reg  [6:0]  HEX1,
    output reg  [6:0]  HEX2,
    output reg  [6:0]  HEX3,
    output reg  [6:0]  HEX4,
    output reg  [6:0]  HEX5
);

// ── Segment encoding (active-low, segments gfedcba) ──────────────────────
function automatic [6:0] seg7;
    input [3:0] digit;
    begin
        case (digit)
            4'd0: seg7 = 7'b1000000; // 0
            4'd1: seg7 = 7'b1111001; // 1
            4'd2: seg7 = 7'b0100100; // 2
            4'd3: seg7 = 7'b0110000; // 3
            4'd4: seg7 = 7'b0011001; // 4
            4'd5: seg7 = 7'b0010010; // 5
            4'd6: seg7 = 7'b0000010; // 6
            4'd7: seg7 = 7'b1111000; // 7
            4'd8: seg7 = 7'b0000000; // 8
            4'd9: seg7 = 7'b0010000; // 9
            default: seg7 = 7'b1111111; // blank
        endcase
    end
endfunction

// ── BCD decomposition ─────────────────────────────────────────────────────
wire [6:0] disp_sec  = (remaining_sec > 16'd99) ? 7'd99 : remaining_sec[6:0];
wire [3:0] sec_ones  = disp_sec % 10;
wire [3:0] sec_tens  = disp_sec / 10;

wire [3:0] spd_ones  = speed_kph % 10;
wire [3:0] spd_tens  = speed_kph / 10;

// ── Drive displays ────────────────────────────────────────────────────────
always @(posedge clk50) begin
    if (!rst_n) begin
        HEX0 <= 7'b1111111;
        HEX1 <= 7'b1111111;
        HEX2 <= 7'b1111111;
        HEX3 <= 7'b1111111;
        HEX4 <= 7'b1111111;
        HEX5 <= 7'b1111111;
    end else begin
        HEX0 <= 7'b1111111;          // unused
        HEX1 <= 7'b1111111;          // unused
        HEX2 <= seg7(spd_ones);      // speed ones
        HEX3 <= seg7(spd_tens);      // speed tens
        HEX4 <= seg7(sec_ones);      // seconds ones
        HEX5 <= seg7(sec_tens);      // seconds tens
    end
end

endmodule
