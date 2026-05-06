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
localparam integer LABEL_N      = 14;
localparam integer LABEL_CELL_W = 6;
localparam integer LABEL_CELL_H = 7;
localparam integer LABEL_X      = (SPRITE_W * SCALE - LABEL_N * LABEL_CELL_W) / 2;
localparam integer LABEL_Y      = 8;
localparam [11:0] C_LABEL       = 12'hA44;

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

function [7:0] label_char;
    input integer idx;
    begin
        case (idx)
            0: label_char = "D";
            1: label_char = "R";
            2: label_char = "I";
            3: label_char = "V";
            4: label_char = "I";
            5: label_char = "N";
            6: label_char = "G";
            7: label_char = " ";
            8: label_char = "S";
            9: label_char = "C";
            10: label_char = "H";
            11: label_char = "O";
            12: label_char = "O";
            13: label_char = "L";
            default: label_char = " ";
        endcase
    end
endfunction

function [4:0] glyph_row;
    input [7:0] ch;
    input [2:0] row;
    begin
        case (ch)
            "C": case (row)
                0: glyph_row = 5'b01110; 1: glyph_row = 5'b10001;
                2: glyph_row = 5'b10000; 3: glyph_row = 5'b10000;
                4: glyph_row = 5'b10000; 5: glyph_row = 5'b10001;
                6: glyph_row = 5'b01110; default: glyph_row = 5'b00000;
            endcase
            "D": case (row)
                0: glyph_row = 5'b11100; 1: glyph_row = 5'b10010;
                2: glyph_row = 5'b10001; 3: glyph_row = 5'b10001;
                4: glyph_row = 5'b10001; 5: glyph_row = 5'b10010;
                6: glyph_row = 5'b11100; default: glyph_row = 5'b00000;
            endcase
            "G": case (row)
                0: glyph_row = 5'b01110; 1: glyph_row = 5'b10001;
                2: glyph_row = 5'b10000; 3: glyph_row = 5'b10111;
                4: glyph_row = 5'b10001; 5: glyph_row = 5'b10001;
                6: glyph_row = 5'b01110; default: glyph_row = 5'b00000;
            endcase
            "H": case (row)
                0: glyph_row = 5'b10001; 1: glyph_row = 5'b10001;
                2: glyph_row = 5'b10001; 3: glyph_row = 5'b11111;
                4: glyph_row = 5'b10001; 5: glyph_row = 5'b10001;
                6: glyph_row = 5'b10001; default: glyph_row = 5'b00000;
            endcase
            "I": case (row)
                0: glyph_row = 5'b11111; 1: glyph_row = 5'b00100;
                2: glyph_row = 5'b00100; 3: glyph_row = 5'b00100;
                4: glyph_row = 5'b00100; 5: glyph_row = 5'b00100;
                6: glyph_row = 5'b11111; default: glyph_row = 5'b00000;
            endcase
            "L": case (row)
                0: glyph_row = 5'b10000; 1: glyph_row = 5'b10000;
                2: glyph_row = 5'b10000; 3: glyph_row = 5'b10000;
                4: glyph_row = 5'b10000; 5: glyph_row = 5'b10000;
                6: glyph_row = 5'b11111; default: glyph_row = 5'b00000;
            endcase
            "N": case (row)
                0: glyph_row = 5'b10001; 1: glyph_row = 5'b11001;
                2: glyph_row = 5'b10101; 3: glyph_row = 5'b10011;
                4: glyph_row = 5'b10001; 5: glyph_row = 5'b10001;
                6: glyph_row = 5'b10001; default: glyph_row = 5'b00000;
            endcase
            "O": case (row)
                0: glyph_row = 5'b01110; 1: glyph_row = 5'b10001;
                2: glyph_row = 5'b10001; 3: glyph_row = 5'b10001;
                4: glyph_row = 5'b10001; 5: glyph_row = 5'b10001;
                6: glyph_row = 5'b01110; default: glyph_row = 5'b00000;
            endcase
            "R": case (row)
                0: glyph_row = 5'b11110; 1: glyph_row = 5'b10001;
                2: glyph_row = 5'b10001; 3: glyph_row = 5'b11110;
                4: glyph_row = 5'b10100; 5: glyph_row = 5'b10010;
                6: glyph_row = 5'b10001; default: glyph_row = 5'b00000;
            endcase
            "S": case (row)
                0: glyph_row = 5'b01111; 1: glyph_row = 5'b10000;
                2: glyph_row = 5'b10000; 3: glyph_row = 5'b01110;
                4: glyph_row = 5'b00001; 5: glyph_row = 5'b00001;
                6: glyph_row = 5'b11110; default: glyph_row = 5'b00000;
            endcase
            "V": case (row)
                0: glyph_row = 5'b10001; 1: glyph_row = 5'b10001;
                2: glyph_row = 5'b10001; 3: glyph_row = 5'b10001;
                4: glyph_row = 5'b10001; 5: glyph_row = 5'b01010;
                6: glyph_row = 5'b00100; default: glyph_row = 5'b00000;
            endcase
            default: glyph_row = 5'b00000;
        endcase
    end
endfunction

function [0:0] label_pixel;
    input [9:0] fpx;
    input [9:0] fpy;
    integer idx;
    reg [9:0] rel_x;
    reg [9:0] rel_y;
    reg [4:0] cell_x;
    reg [4:0] row_bits;
    reg [2:0] glyph_x;
    reg [2:0] glyph_y;
    reg [7:0] ch;
    begin
        label_pixel = 1'b0;
        if (fpx >= x_offset + LABEL_X && fpx < x_offset + LABEL_X + LABEL_N * LABEL_CELL_W &&
            fpy >= y_offset + LABEL_Y && fpy < y_offset + LABEL_Y + LABEL_CELL_H) begin
            rel_x = fpx - (x_offset + LABEL_X);
            rel_y = fpy - (y_offset + LABEL_Y);
            idx = rel_x / LABEL_CELL_W;
            cell_x = rel_x % LABEL_CELL_W;
            glyph_x = cell_x[2:0];
            glyph_y = rel_y[2:0];
            ch = label_char(idx);
            row_bits = glyph_row(ch, glyph_y);
            if (row_bits[4 - glyph_x])
                label_pixel = 1'b1;
        end
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

    if (label_pixel(h_count, v_count)) begin
        rgb = C_LABEL;
    end
end

endmodule