// seg7_display.v — Seven-segment display driver.
//
// Displays:
//   HEX2:HEX1:HEX0 — speed in kph (0–999, padded with zeros)
//   HEX3 — blank (off)
//   HEX5:HEX4 — remaining time SS (countdown seconds)
//   HEX7:HEX6 — coin count (0–15)
//
// DE2 seven-segment segments are active-low.
// Segment map (standard):  gfedcba  (bit 6 = g, bit 0 = a)

module seg7_display (
    input  wire        clk50,
    input  wire        rst_n,
    input  wire [15:0] remaining_sec,
    input  wire [7:0]  speed_kph,
    input  wire [3:0]  coin_count,     // 0–15, from coin_collector
    // DE2 seven-segment outputs (active-low)
    output reg  [6:0]  HEX0,
    output reg  [6:0]  HEX1,
    output reg  [6:0]  HEX2,
    output reg  [6:0]  HEX3,
    output reg  [6:0]  HEX4,
    output reg  [6:0]  HEX5,
    output reg  [6:0]  HEX6,
    output reg  [6:0]  HEX7
);

// ── Segment encoding (active-low, segments gfedcba) ───────────────────────
function automatic [6:0] seg7;
    input [3:0] digit;
    begin
        case (digit)
            4'd0:    seg7 = 7'b1000000;
            4'd1:    seg7 = 7'b1111001;
            4'd2:    seg7 = 7'b0100100;
            4'd3:    seg7 = 7'b0110000;
            4'd4:    seg7 = 7'b0011001;
            4'd5:    seg7 = 7'b0010010;
            4'd6:    seg7 = 7'b0000010;
            4'd7:    seg7 = 7'b1111000;
            4'd8:    seg7 = 7'b0000000;
            4'd9:    seg7 = 7'b0010000;
            default: seg7 = 7'b1111111; // blank
        endcase
    end
endfunction

// ── BCD decomposition ─────────────────────────────────────────────────────
wire [6:0] disp_sec  = (remaining_sec > 16'd99) ? 7'd99 : remaining_sec[6:0];
wire [3:0] sec_ones  = disp_sec % 10;
wire [3:0] sec_tens  = disp_sec / 10;

wire [3:0] spd_ones     = speed_kph % 10;
wire [3:0] spd_tens     = (speed_kph / 10) % 10;
wire [3:0] spd_hundreds = speed_kph / 100;

// coin_count is 0–15; display as two decimal digits (max "15")
wire [3:0] coin_ones = coin_count % 10;
wire [3:0] coin_tens = coin_count / 10;   // will be 0 or 1

// ── Drive displays ────────────────────────────────────────────────────────
always @(posedge clk50) begin
    if (!rst_n) begin
        HEX0 <= 7'b1111111;
        HEX1 <= 7'b1111111;
        HEX2 <= 7'b1111111;
        HEX3 <= 7'b1111111;
        HEX4 <= 7'b1111111;
        HEX5 <= 7'b1111111;
        HEX6 <= 7'b1111111;
        HEX7 <= 7'b1111111;
    end else begin
        // Speed on HEX2:HEX1:HEX0 (3-digit, padded with zeros)
        HEX0 <= seg7(spd_ones);      // speed ones
        HEX1 <= seg7(spd_tens);      // speed tens
        HEX2 <= seg7(spd_hundreds);  // speed hundreds
        HEX3 <= 7'b1111111;          // blank (off)
        // Timer on HEX5:HEX4
        HEX4 <= seg7(sec_ones);      // seconds ones
        HEX5 <= seg7(sec_tens);      // seconds tens
        // Coins on HEX7:HEX6
        HEX6 <= seg7(coin_ones);     // coin ones
        HEX7 <= seg7(coin_tens);     // coin tens (0 or 1)
    end
end

endmodule