// menu_display.v
// Menu screen renderer for VGA output.
// Draws readable bitmap text: "PRESS KEY3" and "TO START".

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
localparam C_ACCENT     = 24'hFFD700;
localparam SKY_H        = 10'd100;

localparam integer CHAR_W  = 5;
localparam integer CHAR_H  = 7;
localparam integer SCALE   = 4;
localparam integer GAP     = 1;
localparam integer CELL_W  = (CHAR_W + GAP) * SCALE;
localparam integer CELL_H  = CHAR_H * SCALE;
localparam integer LINE1_N = 10; // "PRESS KEY3"
localparam integer LINE2_N = 8;  // "TO START"
localparam integer LINE1_X = 200;
localparam integer LINE1_Y = 160;
localparam integer LINE2_X = 224;
localparam integer LINE2_Y = 230;

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
            "E": case (row)
                0: glyph_row = 5'b11111; 1: glyph_row = 5'b10000;
                2: glyph_row = 5'b10000; 3: glyph_row = 5'b11110;
                4: glyph_row = 5'b10000; 5: glyph_row = 5'b10000;
                6: glyph_row = 5'b11111; default: glyph_row = 5'b00000;
            endcase
            "K": case (row)
                0: glyph_row = 5'b10001; 1: glyph_row = 5'b10010;
                2: glyph_row = 5'b10100; 3: glyph_row = 5'b11000;
                4: glyph_row = 5'b10100; 5: glyph_row = 5'b10010;
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
            "Y": case (row)
                0: glyph_row = 5'b10001; 1: glyph_row = 5'b10001;
                2: glyph_row = 5'b01010; 3: glyph_row = 5'b00100;
                4: glyph_row = 5'b00100; 5: glyph_row = 5'b00100;
                6: glyph_row = 5'b00100; default: glyph_row = 5'b00000;
            endcase
            "3": case (row)
                0: glyph_row = 5'b11110; 1: glyph_row = 5'b00001;
                2: glyph_row = 5'b00001; 3: glyph_row = 5'b01110;
                4: glyph_row = 5'b00001; 5: glyph_row = 5'b00001;
                6: glyph_row = 5'b11110; default: glyph_row = 5'b00000;
            endcase
            default: glyph_row = 5'b00000;
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

reg text_on;
integer idx;
integer lx;
integer ly;
integer cell_x;
integer glyph_x;
integer glyph_y;
reg [7:0] ch;

always @(*) begin
    lx = 0;
    ly = 0;
    idx = 0;
    cell_x = 0;
    glyph_x = 0;
    glyph_y = 0;
    ch = 8'h20;

    if (py < SKY_H) begin
        if      (py < (SKY_H/3))   rgb = C_SKY_TOP;
        else if (py < (2*SKY_H/3)) rgb = C_SKY_MID;
        else                        rgb = C_SKY_BOTTOM;
    end else begin
        rgb = C_BG;
    end

    text_on = 1'b0;

    if ((py >= LINE1_Y) && (py < LINE1_Y + CELL_H) &&
        (px >= LINE1_X) && (px < LINE1_X + LINE1_N * CELL_W)) begin
        lx = px - LINE1_X;
        ly = py - LINE1_Y;
        idx = 0;
        cell_x = lx;
        if (lx >= (1 * CELL_W)) begin idx = 1; cell_x = lx - (1 * CELL_W); end
        if (lx >= (2 * CELL_W)) begin idx = 2; cell_x = lx - (2 * CELL_W); end
        if (lx >= (3 * CELL_W)) begin idx = 3; cell_x = lx - (3 * CELL_W); end
        if (lx >= (4 * CELL_W)) begin idx = 4; cell_x = lx - (4 * CELL_W); end
        if (lx >= (5 * CELL_W)) begin idx = 5; cell_x = lx - (5 * CELL_W); end
        if (lx >= (6 * CELL_W)) begin idx = 6; cell_x = lx - (6 * CELL_W); end
        if (lx >= (7 * CELL_W)) begin idx = 7; cell_x = lx - (7 * CELL_W); end
        if (lx >= (8 * CELL_W)) begin idx = 8; cell_x = lx - (8 * CELL_W); end
        if (lx >= (9 * CELL_W)) begin idx = 9; cell_x = lx - (9 * CELL_W); end
        glyph_x = cell_x >> 2;
        glyph_y = ly >> 2;
        if (idx < LINE1_N && glyph_x < CHAR_W && glyph_y < CHAR_H) begin
            ch = line1_char(idx);
            if (glyph_bit(ch, glyph_x[2:0], glyph_y[2:0]))
                text_on = 1'b1;
        end
    end

    if ((py >= LINE2_Y) && (py < LINE2_Y + CELL_H) &&
        (px >= LINE2_X) && (px < LINE2_X + LINE2_N * CELL_W)) begin
        lx = px - LINE2_X;
        ly = py - LINE2_Y;
        idx = 0;
        cell_x = lx;
        if (lx >= (1 * CELL_W)) begin idx = 1; cell_x = lx - (1 * CELL_W); end
        if (lx >= (2 * CELL_W)) begin idx = 2; cell_x = lx - (2 * CELL_W); end
        if (lx >= (3 * CELL_W)) begin idx = 3; cell_x = lx - (3 * CELL_W); end
        if (lx >= (4 * CELL_W)) begin idx = 4; cell_x = lx - (4 * CELL_W); end
        if (lx >= (5 * CELL_W)) begin idx = 5; cell_x = lx - (5 * CELL_W); end
        if (lx >= (6 * CELL_W)) begin idx = 6; cell_x = lx - (6 * CELL_W); end
        if (lx >= (7 * CELL_W)) begin idx = 7; cell_x = lx - (7 * CELL_W); end
        glyph_x = cell_x >> 2;
        glyph_y = ly >> 2;
        if (idx < LINE2_N && glyph_x < CHAR_W && glyph_y < CHAR_H) begin
            ch = line2_char(idx);
            if (glyph_bit(ch, glyph_x[2:0], glyph_y[2:0]))
                text_on = 1'b1;
        end
    end

    if (text_on)
        rgb = C_TEXT;

    if (py >= 10'd330 && py <= 10'd345 && px >= 10'd160 && px <= 10'd480) begin
        if (((px >> 3) ^ (py >> 2)) & 1'b1)
            rgb = C_ACCENT;
    end
end

endmodule
