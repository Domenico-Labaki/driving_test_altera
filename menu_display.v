// menu_display.v
// Menu screen renderer for VGA output.
// Draws readable bitmap text:
//   Line 0: "DRIVER'S" (title, large scale)
//   Line 1: "LICENSE"  (title, large scale)
//   Line 2: "BEIRUT DRIFT" (subtitle, medium scale)
//   Line 3: "PRESS KEY3"
//   Line 4: "TO START"

module menu_display (
    input  wire [9:0]  px,
    input  wire [9:0]  py,
    output reg  [23:0] rgb
);

localparam C_SKY_TOP    = 24'h9BD6F8;
localparam C_SKY_MID    = 24'h7ECFF0;
localparam C_SKY_BOTTOM = 24'h5FBEE8;
localparam C_BG         = 24'h1A3A4A;
localparam C_TEXT       = 24'hFFFFFF;
localparam C_TITLE      = 24'hFFD700;   // gold
localparam C_TITLE_SHAD = 24'h884400;   // dark amber shadow
localparam C_SUBTITLE   = 24'hFF8800;   // orange
localparam C_ACCENT     = 24'hFFD700;
localparam SKY_H        = 10'd100;

// ── Font geometry ──────────────────────────────────────────────────────────
localparam integer CHAR_W  = 5;
localparam integer CHAR_H  = 7;
localparam integer GAP     = 1;

// Title lines: scale 5 (large, retro-chunky)
localparam integer T_SCALE  = 5;
localparam integer T_CELL_W = (CHAR_W + GAP) * T_SCALE;   // 30
localparam integer T_CELL_H = CHAR_H * T_SCALE;            // 35

// Subtitle line: scale 3
localparam integer S_SCALE  = 3;
localparam integer S_CELL_W = (CHAR_W + GAP) * S_SCALE;   // 18
localparam integer S_CELL_H = CHAR_H * S_SCALE;            // 21

// Instruction lines: scale 4 (unchanged)
localparam integer I_SCALE  = 4;
localparam integer I_CELL_W = (CHAR_W + GAP) * I_SCALE;   // 24
localparam integer I_CELL_H = CHAR_H * I_SCALE;            // 28

// ── Text content ──────────────────────────────────────────────────────────
// Title row 0: "DRIVER'S"  (8 chars)
localparam integer TITLE0_N = 8;
localparam integer TITLE0_X = 320 - (TITLE0_N * T_CELL_W) / 2;  // centred
localparam integer TITLE0_Y = 115;

// Title row 1: "LICENSE"   (7 chars)
localparam integer TITLE1_N = 7;
localparam integer TITLE1_X = 320 - (TITLE1_N * T_CELL_W) / 2;
localparam integer TITLE1_Y = TITLE0_Y + T_CELL_H + 4;           // 154

// Subtitle: "BEIRUT DRIFT"  (12 chars incl space)
localparam integer SUB_N    = 12;
localparam integer SUB_X    = 320 - (SUB_N * S_CELL_W) / 2;
localparam integer SUB_Y    = TITLE1_Y + T_CELL_H + 8;           // 197

// Instruction line 1: "PRESS KEY3"
localparam integer LINE1_N  = 10;
localparam integer LINE1_X  = 320 - (LINE1_N * I_CELL_W) / 2;
localparam integer LINE1_Y  = SUB_Y + S_CELL_H + 26;             // ~244

// Instruction line 2: "TO START"
localparam integer LINE2_N  = 8;
localparam integer LINE2_X  = 320 - (LINE2_N * I_CELL_W) / 2;
localparam integer LINE2_Y  = LINE1_Y + I_CELL_H + 8;            // ~280

// ── Character ROM functions ────────────────────────────────────────────────
function [7:0] title0_char;
    input integer idx;
    begin
        case (idx)
            0: title0_char = "D";
            1: title0_char = "R";
            2: title0_char = "I";
            3: title0_char = "V";
            4: title0_char = "E";
            5: title0_char = "R";
            6: title0_char = "'";
            7: title0_char = "S";
            default: title0_char = " ";
        endcase
    end
endfunction

function [7:0] title1_char;
    input integer idx;
    begin
        case (idx)
            0: title1_char = "L";
            1: title1_char = "I";
            2: title1_char = "C";
            3: title1_char = "E";
            4: title1_char = "N";
            5: title1_char = "S";
            6: title1_char = "E";
            default: title1_char = " ";
        endcase
    end
endfunction

function [7:0] sub_char;
    input integer idx;
    begin
        case (idx)
            0: sub_char = "B";
            1: sub_char = "E";
            2: sub_char = "I";
            3: sub_char = "R";
            4: sub_char = "U";
            5: sub_char = "T";
            6: sub_char = " ";
            7: sub_char = "D";
            8: sub_char = "R";
            9: sub_char = "I";
           10: sub_char = "F";
           11: sub_char = "T";
            default: sub_char = " ";
        endcase
    end
endfunction

function [7:0] line1_char;
    input integer idx;
    begin
        case (idx)
            0: line1_char = "P";
            1: line1_char = "R";
            2: line1_char = "E";
            3: line1_char = "S";
            4: line1_char = "S";
            5: line1_char = " ";
            6: line1_char = "K";
            7: line1_char = "E";
            8: line1_char = "Y";
            9: line1_char = "3";
            default: line1_char = " ";
        endcase
    end
endfunction

function [7:0] line2_char;
    input integer idx;
    begin
        case (idx)
            0: line2_char = "T";
            1: line2_char = "O";
            2: line2_char = " ";
            3: line2_char = "S";
            4: line2_char = "T";
            5: line2_char = "A";
            6: line2_char = "R";
            7: line2_char = "T";
            default: line2_char = " ";
        endcase
    end
endfunction

// ── 5×7 glyph ROM ─────────────────────────────────────────────────────────
function [4:0] glyph_row;
    input [7:0] ch;
    input [2:0] row;
    begin
        case (ch)
            "A": case (row)
                0: glyph_row = 5'b01110; 1: glyph_row = 5'b10001;
                2: glyph_row = 5'b10001; 3: glyph_row = 5'b11111;
                4: glyph_row = 5'b10001; 5: glyph_row = 5'b10001;
                6: glyph_row = 5'b10001; default: glyph_row = 5'b00000;
            endcase
            "B": case (row)
                0: glyph_row = 5'b11110; 1: glyph_row = 5'b10001;
                2: glyph_row = 5'b10001; 3: glyph_row = 5'b11110;
                4: glyph_row = 5'b10001; 5: glyph_row = 5'b10001;
                6: glyph_row = 5'b11110; default: glyph_row = 5'b00000;
            endcase
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
            "E": case (row)
                0: glyph_row = 5'b11111; 1: glyph_row = 5'b10000;
                2: glyph_row = 5'b10000; 3: glyph_row = 5'b11110;
                4: glyph_row = 5'b10000; 5: glyph_row = 5'b10000;
                6: glyph_row = 5'b11111; default: glyph_row = 5'b00000;
            endcase
            "F": case (row)
                0: glyph_row = 5'b11111; 1: glyph_row = 5'b10000;
                2: glyph_row = 5'b10000; 3: glyph_row = 5'b11110;
                4: glyph_row = 5'b10000; 5: glyph_row = 5'b10000;
                6: glyph_row = 5'b10000; default: glyph_row = 5'b00000;
            endcase
            "I": case (row)
                0: glyph_row = 5'b11111; 1: glyph_row = 5'b00100;
                2: glyph_row = 5'b00100; 3: glyph_row = 5'b00100;
                4: glyph_row = 5'b00100; 5: glyph_row = 5'b00100;
                6: glyph_row = 5'b11111; default: glyph_row = 5'b00000;
            endcase
            "K": case (row)
                0: glyph_row = 5'b10001; 1: glyph_row = 5'b10010;
                2: glyph_row = 5'b10100; 3: glyph_row = 5'b11000;
                4: glyph_row = 5'b10100; 5: glyph_row = 5'b10010;
                6: glyph_row = 5'b10001; default: glyph_row = 5'b00000;
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
            "P": case (row)
                0: glyph_row = 5'b11110; 1: glyph_row = 5'b10001;
                2: glyph_row = 5'b10001; 3: glyph_row = 5'b11110;
                4: glyph_row = 5'b10000; 5: glyph_row = 5'b10000;
                6: glyph_row = 5'b10000; default: glyph_row = 5'b00000;
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
            "T": case (row)
                0: glyph_row = 5'b11111; 1: glyph_row = 5'b00100;
                2: glyph_row = 5'b00100; 3: glyph_row = 5'b00100;
                4: glyph_row = 5'b00100; 5: glyph_row = 5'b00100;
                6: glyph_row = 5'b00100; default: glyph_row = 5'b00000;
            endcase
            "U": case (row)
                0: glyph_row = 5'b10001; 1: glyph_row = 5'b10001;
                2: glyph_row = 5'b10001; 3: glyph_row = 5'b10001;
                4: glyph_row = 5'b10001; 5: glyph_row = 5'b10001;
                6: glyph_row = 5'b01110; default: glyph_row = 5'b00000;
            endcase
            "V": case (row)
                0: glyph_row = 5'b10001; 1: glyph_row = 5'b10001;
                2: glyph_row = 5'b10001; 3: glyph_row = 5'b10001;
                4: glyph_row = 5'b10001; 5: glyph_row = 5'b01010;
                6: glyph_row = 5'b00100; default: glyph_row = 5'b00000;
            endcase
            "Y": case (row)
                0: glyph_row = 5'b10001; 1: glyph_row = 5'b10001;
                2: glyph_row = 5'b01010; 3: glyph_row = 5'b00100;
                4: glyph_row = 5'b00100; 5: glyph_row = 5'b00100;
                6: glyph_row = 5'b00100; default: glyph_row = 5'b00000;
            endcase
            "'": case (row)   // apostrophe — top 3 rows only
                0: glyph_row = 5'b00100; 1: glyph_row = 5'b00100;
                2: glyph_row = 5'b01000; 3: glyph_row = 5'b00000;
                4: glyph_row = 5'b00000; 5: glyph_row = 5'b00000;
                6: glyph_row = 5'b00000; default: glyph_row = 5'b00000;
            endcase
            "3": case (row)
                0: glyph_row = 5'b11110; 1: glyph_row = 5'b00001;
                2: glyph_row = 5'b00001; 3: glyph_row = 5'b01110;
                4: glyph_row = 5'b00001; 5: glyph_row = 5'b00001;
                6: glyph_row = 5'b11110; default: glyph_row = 5'b00000;
            endcase
            default: glyph_row = 5'b00000;  // space or unknown
        endcase
    end
endfunction

function glyph_bit;
    input [7:0] ch;
    input [2:0] gx;
    input [2:0] gy;
    reg [4:0] row_bits;
    begin
        row_bits = glyph_row(ch, gy);
        glyph_bit = row_bits[4-gx];
    end
endfunction

// ── Helper: decode character index from x offset for each line ────────────
// Returns the char index and intra-cell x for a given line (avoids duplicate
// if/else chains).  Written out per line for synthesis simplicity.

// ── Pixel renderer ─────────────────────────────────────────────────────────
reg  text_on;
reg  title_on;
reg  sub_on;

integer idx;
integer lx, ly;
integer cell_x, glyph_x, glyph_y;
reg [7:0] ch;

// Macro-style decode: given lx and CELL_W, compute idx and cell_x.
// Verilog doesn't allow parameterised tasks easily so we write it inline.

task decode_char;
    input integer raw_lx;
    input integer cw;
    input integer n;
    output integer o_idx;
    output integer o_cell_x;
    integer i;
    begin
        o_idx    = 0;
        o_cell_x = raw_lx;
        for (i = 1; i < n; i = i + 1) begin
            if (raw_lx >= i * cw) begin
                o_idx    = i;
                o_cell_x = raw_lx - i * cw;
            end
        end
    end
endtask

always @(*) begin
    // ── Background ──────────────────────────────────────────────────────
    if (py < SKY_H) begin
        if      (py < (SKY_H/3))   rgb = C_SKY_TOP;
        else if (py < (2*SKY_H/3)) rgb = C_SKY_MID;
        else                        rgb = C_SKY_BOTTOM;
    end else begin
        rgb = C_BG;
    end

    // ── Accent strip (checkered, like road markings) ──────────────────
    if (py >= 10'd318 && py <= 10'd323 && px >= 10'd160 && px <= 10'd480) begin
        if (((px >> 3) ^ (py >> 1)) & 1'b1)
            rgb = C_ACCENT;
    end

    // ── Title shadow (offset +2,+2) — drawn first so main is on top ──
    title_on  = 1'b0;

    // Shadow: DRIVER'S (title row 0)
    if ((py >= TITLE0_Y + 2) && (py < TITLE0_Y + 2 + T_CELL_H) &&
        (px >= TITLE0_X + 2) && (px < TITLE0_X + 2 + TITLE0_N * T_CELL_W)) begin
        lx = px - (TITLE0_X + 2);
        ly = py - (TITLE0_Y + 2);
        decode_char(lx, T_CELL_W, TITLE0_N, idx, cell_x);
        glyph_x = cell_x / T_SCALE;
        glyph_y = ly / T_SCALE;
        if (glyph_x < CHAR_W && glyph_y < CHAR_H) begin
            ch = title0_char(idx);
            if (glyph_bit(ch, glyph_x[2:0], glyph_y[2:0]))
                rgb = C_TITLE_SHAD;
        end
    end

    // Shadow: LICENSE (title row 1)
    if ((py >= TITLE1_Y + 2) && (py < TITLE1_Y + 2 + T_CELL_H) &&
        (px >= TITLE1_X + 2) && (px < TITLE1_X + 2 + TITLE1_N * T_CELL_W)) begin
        lx = px - (TITLE1_X + 2);
        ly = py - (TITLE1_Y + 2);
        decode_char(lx, T_CELL_W, TITLE1_N, idx, cell_x);
        glyph_x = cell_x / T_SCALE;
        glyph_y = ly / T_SCALE;
        if (glyph_x < CHAR_W && glyph_y < CHAR_H) begin
            ch = title1_char(idx);
            if (glyph_bit(ch, glyph_x[2:0], glyph_y[2:0]))
                rgb = C_TITLE_SHAD;
        end
    end

    // ── Title gold pixels ─────────────────────────────────────────────
    // DRIVER'S
    if ((py >= TITLE0_Y) && (py < TITLE0_Y + T_CELL_H) &&
        (px >= TITLE0_X) && (px < TITLE0_X + TITLE0_N * T_CELL_W)) begin
        lx = px - TITLE0_X;
        ly = py - TITLE0_Y;
        decode_char(lx, T_CELL_W, TITLE0_N, idx, cell_x);
        glyph_x = cell_x / T_SCALE;
        glyph_y = ly / T_SCALE;
        if (glyph_x < CHAR_W && glyph_y < CHAR_H) begin
            ch = title0_char(idx);
            if (glyph_bit(ch, glyph_x[2:0], glyph_y[2:0])) begin
                rgb = C_TITLE;
                title_on = 1'b1;
            end
        end
    end

    // LICENSE
    if ((py >= TITLE1_Y) && (py < TITLE1_Y + T_CELL_H) &&
        (px >= TITLE1_X) && (px < TITLE1_X + TITLE1_N * T_CELL_W)) begin
        lx = px - TITLE1_X;
        ly = py - TITLE1_Y;
        decode_char(lx, T_CELL_W, TITLE1_N, idx, cell_x);
        glyph_x = cell_x / T_SCALE;
        glyph_y = ly / T_SCALE;
        if (glyph_x < CHAR_W && glyph_y < CHAR_H) begin
            ch = title1_char(idx);
            if (glyph_bit(ch, glyph_x[2:0], glyph_y[2:0])) begin
                rgb = C_TITLE;
                title_on = 1'b1;
            end
        end
    end

    // ── Subtitle: BEIRUT DRIFT (orange) ───────────────────────────────
    sub_on = 1'b0;
    if ((py >= SUB_Y) && (py < SUB_Y + S_CELL_H) &&
        (px >= SUB_X) && (px < SUB_X + SUB_N * S_CELL_W)) begin
        lx = px - SUB_X;
        ly = py - SUB_Y;
        decode_char(lx, S_CELL_W, SUB_N, idx, cell_x);
        glyph_x = cell_x / S_SCALE;
        glyph_y = ly / S_SCALE;
        if (glyph_x < CHAR_W && glyph_y < CHAR_H) begin
            ch = sub_char(idx);
            if (glyph_bit(ch, glyph_x[2:0], glyph_y[2:0])) begin
                rgb = C_SUBTITLE;
                sub_on = 1'b1;
            end
        end
    end

    // ── Instruction text ──────────────────────────────────────────────
    text_on = 1'b0;

    // PRESS KEY3
    if ((py >= LINE1_Y) && (py < LINE1_Y + I_CELL_H) &&
        (px >= LINE1_X) && (px < LINE1_X + LINE1_N * I_CELL_W)) begin
        lx = px - LINE1_X;
        ly = py - LINE1_Y;
        decode_char(lx, I_CELL_W, LINE1_N, idx, cell_x);
        glyph_x = cell_x / I_SCALE;
        glyph_y = ly / I_SCALE;
        if (glyph_x < CHAR_W && glyph_y < CHAR_H) begin
            ch = line1_char(idx);
            if (glyph_bit(ch, glyph_x[2:0], glyph_y[2:0]))
                text_on = 1'b1;
        end
    end

    // TO START
    if ((py >= LINE2_Y) && (py < LINE2_Y + I_CELL_H) &&
        (px >= LINE2_X) && (px < LINE2_X + LINE2_N * I_CELL_W)) begin
        lx = px - LINE2_X;
        ly = py - LINE2_Y;
        decode_char(lx, I_CELL_W, LINE2_N, idx, cell_x);
        glyph_x = cell_x / I_SCALE;
        glyph_y = ly / I_SCALE;
        if (glyph_x < CHAR_W && glyph_y < CHAR_H) begin
            ch = line2_char(idx);
            if (glyph_bit(ch, glyph_x[2:0], glyph_y[2:0]))
                text_on = 1'b1;
        end
    end

    if (text_on)
        rgb = C_TEXT;
end

endmodule