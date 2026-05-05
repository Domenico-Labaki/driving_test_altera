// driving_school_display.v
// Renders a pixel-art "Driving School" building on a VGA display.
//
// Output: 12-bit RGB (4R 4G 4B) — 12'h000 means "not my pixel" (transparent).
// The caller in track_renderer expands it to 24-bit.
//
// Sprite dimensions : SPRITE_W × SPRITE_H = 30 × 27  pixels
//                     Each source pixel is scaled × SCALE (4)
//                     → 120 × 108 display pixels
//
// Position on screen : top-left corner at (x_offset, y_offset)
//
// NOTE: The sprite ROM uses a flat function (row*SPRITE_W + col) with a
// case statement so Quartus infers a proper synchronous ROM rather than
// relying on 2D-array initial-block synthesis (unreliable on Cyclone II).

module driving_school_display (
    input  wire [9:0]  h_count,
    input  wire [9:0]  v_count,
    input  wire [9:0]  x_offset,
    input  wire [9:0]  y_offset,
    output reg  [11:0] rgb          // 12-bit; 12'h000 = transparent
);

localparam SPRITE_W = 30;
localparam SPRITE_H = 27;
localparam SCALE    = 4;

// ── Palette ────────────────────────────────────────────────────────────────
// 0  transparent
// 1  dark red/brown outline   12'hA44
// 2  red/brown body           12'hC66
// 3  white wall               12'hFFF
// 4  medium brown band        12'hA54
// 5  bright yellow window     12'hFF0
// 6  dark brown garage/door   12'h553
// 7  dark brown roof shadow   12'h743
// 8  light grey step          12'hBBB
// 9  cream sign background    12'hFDB
// 10 red accent               12'hF33

// ── Flat ROM: index = row*30 + col, total 810 entries ─────────────────────
// Palette values encoded row by row.
// Row layout (Y downward):
//   0-1   : chimneys only (rest transparent)
//   2-3   : transparent sky
//   4-6   : brown cornice band / white stripe
//   7-9   : white wall, upper floor
//   10-12 : white wall with yellow windows
//   13-15 : white wall, mid floor  
//   16-18 : white wall with yellow windows, lower floor
//   19-22 : garage + cream sign strip
//   23-24 : grey step
//   25-26 : transparent (ground)

function [3:0] rom_val;
    input [9:0] addr;   // row*30 + col, 0..809
    reg [4:0] r;
    reg [4:0] c;
    begin
        r = addr / 30;
        c = addr % 30;
        // default transparent
        rom_val = 4'd0;

        // ── Chimneys (rows 0-1) ──────────────────────────────────────────
        if (r <= 1) begin
            if (c==5'd4 || c==5'd6 || c==5'd23 || c==5'd25) rom_val = 4'd1;
            else if (c==5'd5 || c==5'd24)                    rom_val = 4'd2;
            else                                              rom_val = 4'd0;
        end

        // ── Rows 2-3: transparent ────────────────────────────────────────
        else if (r <= 3) rom_val = 4'd0;

        // ── Rows 4-6: cornice band (brown, white stripe on row 5) ────────
        else if (r <= 6) begin
            if (c==0 || c==29)                rom_val = 4'd1; // side outline
            else if (c==11 || c==18)          rom_val = 4'd1; // chimney gaps
            else if (r==5)                    rom_val = 4'd3; // white stripe
            else                              rom_val = 4'd4; // brown band
        end

        // ── Rows 7-9: upper white wall ────────────────────────────────────
        else if (r <= 9) begin
            if (c==0 || c==29)   rom_val = 4'd1;
            else if (c==11)      rom_val = 4'd1; // interior divider
            else if (c==18)      rom_val = 4'd1;
            else                 rom_val = 4'd3;
        end

        // ── Rows 10-12: white wall + windows ─────────────────────────────
        else if (r <= 12) begin
            if (c==0 || c==29)   rom_val = 4'd1;
            else if (c==11 || c==18) rom_val = 4'd1;
            // Window columns: 3-5, 13-15, 20-22, 25-27
            else if ((c>=3  && c<=5)  ||
                     (c>=13 && c<=15) ||
                     (c>=20 && c<=22) ||
                     (c>=25 && c<=27)) rom_val = 4'd5; // yellow window
            else                 rom_val = 4'd3;
        end

        // ── Rows 13-15: white wall ────────────────────────────────────────
        else if (r <= 15) begin
            if (c==0 || c==29)   rom_val = 4'd1;
            else if (c==11 || c==18) rom_val = 4'd1;
            else                 rom_val = 4'd3;
        end

        // ── Rows 16-18: white wall + windows (lower floor) ───────────────
        else if (r <= 18) begin
            if (c==0 || c==29)   rom_val = 4'd1;
            else if (c==11 || c==18) rom_val = 4'd1;
            else if ((c>=3  && c<=5)  ||
                     (c>=13 && c<=15) ||
                     (c>=20 && c<=22) ||
                     (c>=25 && c<=27)) rom_val = 4'd5;
            else                 rom_val = 4'd3;
        end

        // ── Rows 19-22: garage door (left/right) + cream sign (centre) ───
        else if (r <= 22) begin
            if (c==0 || c==29)         rom_val = 4'd1;  // outline
            else if (c>=1  && c<=4)    rom_val = 4'd6;  // left garage (dark)
            else if (c>=5  && c<=24)   rom_val = 4'd9;  // sign (cream)
            else if (c>=25 && c<=28)   rom_val = 4'd6;  // right entrance (dark)
        end

        // ── Rows 23-24: grey step ─────────────────────────────────────────
        else if (r <= 24) begin
            if (c==0 || c==29) rom_val = 4'd1;
            else               rom_val = 4'd8;
        end

        // ── Rows 25-26: transparent ───────────────────────────────────────
        else rom_val = 4'd0;
    end
endfunction

// ── Coordinate math ───────────────────────────────────────────────────────
wire signed [10:0] rel_x = $signed({1'b0, h_count}) - $signed({1'b0, x_offset});
wire signed [10:0] rel_y = $signed({1'b0, v_count}) - $signed({1'b0, y_offset});

wire in_bounds = (rel_x >= 0) && (rel_x < (SPRITE_W * SCALE)) &&
                 (rel_y >= 0) && (rel_y < (SPRITE_H * SCALE));

// Divide by SCALE=4 (right-shift 2)
wire [4:0] sp_col = rel_x[6:2];
wire [4:0] sp_row = rel_y[6:2];

wire [9:0] rom_addr = ({5'b0, sp_row} * 10'd30) + {5'b0, sp_col};

wire [3:0] pal_idx = in_bounds ? rom_val(rom_addr) : 4'd0;

// ── Palette output ────────────────────────────────────────────────────────
always @(*) begin
    if (!in_bounds || pal_idx == 4'd0) begin
        rgb = 12'h000;
    end else begin
        case (pal_idx)
            4'd1:    rgb = 12'hA44;
            4'd2:    rgb = 12'hC66;
            4'd3:    rgb = 12'hFFF;
            4'd4:    rgb = 12'hA54;
            4'd5:    rgb = 12'hFF0;
            4'd6:    rgb = 12'h553;
            4'd7:    rgb = 12'h743;
            4'd8:    rgb = 12'hBBB;
            4'd9:    rgb = 12'hFDB;
            4'd10:   rgb = 12'hF33;
            default: rgb = 12'h000;
        endcase
    end
end

endmodule