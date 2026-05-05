// driving_school_display.v
// Renders a pixel-art "Driving School" building on a VGA display.
//
// Output: 12-bit RGB (4R 4G 4B) — 12'h000 means "not my pixel" (transparent).
// The caller in track_renderer expands it to 24-bit:
//   {rgb[11:8],rgb[11:8], rgb[7:4],rgb[7:4], rgb[3:0],rgb[3:0]}
//
// Sprite dimensions : SPRITE_W × SPRITE_H = 30 × 27  pixels
//                     Each source pixel is scaled × SCALE (default 4)
//                     → 120 × 108 display pixels
//
// Position on screen : top-left corner at (x_offset, y_offset)
//   caller passes 10'd50, 10'd15  (sky band)

module driving_school_display (
    input  wire        pixel_clk,
    input  wire [9:0]  h_count,
    input  wire [9:0]  v_count,
    input  wire [9:0]  x_offset,
    input  wire [9:0]  y_offset,
    output reg  [11:0] rgb          // 12-bit; 12'h000 = transparent
);

// ── Sprite parameters ──────────────────────────────────────────────────────
localparam SPRITE_W = 30;
localparam SPRITE_H = 27;
localparam SCALE    = 4;   // each sprite pixel = 4×4 display pixels

// ── Palette (4-bit per channel → 12-bit) ──────────────────────────────────
//   0  transparent / off
//   1  dark grey outline        #222  → 12'h222
//   2  maroon body              #802  → 12'h802
//   3  white / light grey wall  #EEE  → 12'hEEE
//   4  dark maroon band         #601  → 12'h601
//   5  yellow window            #FD0  → 12'hFD0
//   6  black window / garage    #000  → 12'h111  (pure black=transparent so use 111)
//   7  dark roof shadow         #400  → 12'h400
//   8  mid grey step            #888  → 12'h888
//   9  door sign bg (cream)     #EDB  → 12'hEDB
//  10  red flag / accent        #C00  → 12'hC00
//  11  light sky fill           #9CF  → 12'h9CF   (not used in sprite; for reference)

localparam [11:0] PAL [0:11];
assign PAL[0]  = 12'h000;   // transparent
assign PAL[1]  = 12'h222;   // outline
assign PAL[2]  = 12'h802;   // maroon
assign PAL[3]  = 12'hEEE;   // wall
assign PAL[4]  = 12'h601;   // dark maroon
assign PAL[5]  = 12'hFD0;   // yellow window
assign PAL[6]  = 12'h111;   // black (garage / shadow)
assign PAL[7]  = 12'h400;   // dark roof
assign PAL[8]  = 12'h888;   // mid-grey step
assign PAL[9]  = 12'hEDB;   // sign background
assign PAL[10] = 12'hC00;   // red accent
assign PAL[11] = 12'h9CF;   // light sky (unused but reserved)

// ── Sprite ROM — 30 columns × 27 rows, 4 bits per pixel ───────────────────
// Each row is a 120-bit vector: pixel[0] in MSB .. pixel[29] in LSB
// (pixel column 0 = leftmost = bits [119:116])
//
// Row layout (top = row 0):
//  0-1   : chimney / upper roof edge
//  2-4   : main roof (maroon)
//  5-6   : roof-to-wall transition + cornice
//  7-10  : 2nd floor (maroon band + windows + white sections)
//  11-12 : inter-floor stripe
//  13-16 : 1st floor (same pattern)
//  17-18 : base band / garage level top
//  19-22 : garage + sign + door
//  23-24 : step / kerb
//  25-26 : ground shadow

// Encoding helper: each nibble is one palette index.
// 30 nibbles = 120 bits per row stored as 30 hex digits (read L→R = col 0→29).

reg [3:0] sprite_rom [0:SPRITE_H-1][0:SPRITE_W-1];

integer init_r, init_c;
// Pixel data encoded row by row (palette index per pixel):
//   Abbreviations used in comments:
//   T=transparent(0) O=outline(1) M=maroon(2) W=wall(3)
//   D=darkMaroon(4)  Y=yellow(5)  B=black(6)  R=darkRoof(7)
//   G=grey(8)        S=sign(9)    X=redAccent(10)

// We use an initial block to fill the ROM with the sprite data.
initial begin
    //  --- Row 0: chimney stubs (narrow columns at ~col 4-5 and 24-25) ---
    begin : r0
        integer c;
        for (c=0;c<SPRITE_W;c=c+1) sprite_rom[0][c] = 4'd0;
        sprite_rom[0][4]=4'd1; sprite_rom[0][5]=4'd2; sprite_rom[0][6]=4'd1;
        sprite_rom[0][23]=4'd1; sprite_rom[0][24]=4'd2; sprite_rom[0][25]=4'd1;
    end
    //  --- Row 1: chimney body ---
    begin : r1
        integer c;
        for (c=0;c<SPRITE_W;c=c+1) sprite_rom[1][c] = 4'd0;
        sprite_rom[1][4]=4'd1; sprite_rom[1][5]=4'd2; sprite_rom[1][6]=4'd1;
        sprite_rom[1][23]=4'd1; sprite_rom[1][24]=4'd2; sprite_rom[1][25]=4'd1;
    end
    //  --- Row 2: upper roof left wing peak + right wing ---
    begin : r2
        integer c;
        for (c=0;c<SPRITE_W;c=c+1) sprite_rom[2][c] = 4'd0;
        // Left wing: cols 0-9
        sprite_rom[2][2]=4'd1;
        for (c=3;c<=8;c=c+1) sprite_rom[2][c]=4'd2;
        sprite_rom[2][9]=4'd1;
        // Centre tower: cols 12-17
        sprite_rom[2][12]=4'd1;
        for (c=13;c<=16;c=c+1) sprite_rom[2][c]=4'd2;
        sprite_rom[2][17]=4'd1;
        // Right wing: cols 20-28
        sprite_rom[2][20]=4'd1;
        for (c=21;c<=27;c=c+1) sprite_rom[2][c]=4'd2;
        sprite_rom[2][28]=4'd1;
    end
    //  --- Row 3: roof fill ---
    begin : r3
        integer c;
        for (c=0;c<SPRITE_W;c=c+1) sprite_rom[3][c] = 4'd0;
        sprite_rom[3][1]=4'd1;
        for (c=2;c<=10;c=c+1) sprite_rom[3][c]=4'd2;
        sprite_rom[3][11]=4'd1;
        sprite_rom[3][12]=4'd1;
        for (c=13;c<=16;c=c+1) sprite_rom[3][c]=4'd4;
        sprite_rom[3][17]=4'd1;
        sprite_rom[3][18]=4'd1;
        for (c=19;c<=28;c=c+1) sprite_rom[3][c]=4'd2;
        sprite_rom[3][29]=4'd1;
    end
    //  --- Row 4: roof bottom edge with dark maroon band ---
    begin : r4
        integer c;
        for (c=0;c<SPRITE_W;c=c+1) sprite_rom[4][c] = 4'd1;
        for (c=1;c<=10;c=c+1) sprite_rom[4][c]=4'd4;
        sprite_rom[4][11]=4'd1;
        for (c=12;c<=17;c=c+1) sprite_rom[4][c]=4'd4;
        sprite_rom[4][18]=4'd1;
        for (c=19;c<=28;c=c+1) sprite_rom[4][c]=4'd4;
    end
    //  --- Row 5: cornice / wall top — white stripe ---
    begin : r5
        integer c;
        for (c=0;c<SPRITE_W;c=c+1) sprite_rom[5][c] = 4'd1;
        for (c=1;c<=10;c=c+1) sprite_rom[5][c]=4'd3;
        // gap col 11 = outline
        for (c=12;c<=17;c=c+1) sprite_rom[5][c]=4'd3;
        // gap col 18 = outline
        for (c=19;c<=28;c=c+1) sprite_rom[5][c]=4'd3;
    end
    //  --- Row 6: maroon band (2nd floor top) ---
    begin : r6
        integer c;
        for (c=0;c<SPRITE_W;c=c+1) sprite_rom[6][c] = 4'd1;
        for (c=1;c<=10;c=c+1) sprite_rom[6][c]=4'd2;
        for (c=12;c<=17;c=c+1) sprite_rom[6][c]=4'd2;
        for (c=19;c<=28;c=c+1) sprite_rom[6][c]=4'd2;
    end
    //  --- Rows 7-9: 2nd floor with windows ---
    // Pattern per wing: [M][W][W][Y][Y][W][W][M]
    // Left (cols 1-10): M W W Y Y W W M (M=maroon ends, W=wall, Y=window)
    // Right (cols 19-28): same
    // Centre tower (12-17): narrow M Y Y M
    begin : r789
        integer r,c;
        for (r=7;r<=9;r=r+1) begin
            for (c=0;c<SPRITE_W;c=c+1) sprite_rom[r][c] = 4'd1;
            // left wing
            sprite_rom[r][1]=4'd2; sprite_rom[r][2]=4'd3;
            sprite_rom[r][3]=4'd5; sprite_rom[r][4]=4'd5;
            sprite_rom[r][5]=4'd3; sprite_rom[r][6]=4'd3;
            sprite_rom[r][7]=4'd5; sprite_rom[r][8]=4'd5;
            sprite_rom[r][9]=4'd3; sprite_rom[r][10]=4'd2;
            // centre tower
            sprite_rom[r][12]=4'd2; sprite_rom[r][13]=4'd3;
            sprite_rom[r][14]=4'd3; sprite_rom[r][15]=4'd3;
            sprite_rom[r][16]=4'd3; sprite_rom[r][17]=4'd2;
            // right wing
            sprite_rom[r][19]=4'd2; sprite_rom[r][20]=4'd3;
            sprite_rom[r][21]=4'd5; sprite_rom[r][22]=4'd5;
            sprite_rom[r][23]=4'd3; sprite_rom[r][24]=4'd3;
            sprite_rom[r][25]=4'd5; sprite_rom[r][26]=4'd5;
            sprite_rom[r][27]=4'd3; sprite_rom[r][28]=4'd2;
        end
        // Row 7: window tops (slightly darker top line of window = outline)
        sprite_rom[7][3]=4'd1; sprite_rom[7][4]=4'd1;
        sprite_rom[7][7]=4'd1; sprite_rom[7][8]=4'd1;
        sprite_rom[7][21]=4'd1; sprite_rom[7][22]=4'd1;
        sprite_rom[7][25]=4'd1; sprite_rom[7][26]=4'd1;
    end
    //  --- Row 10: bottom maroon band of 2nd floor ---
    begin : r10
        integer c;
        for (c=0;c<SPRITE_W;c=c+1) sprite_rom[10][c] = 4'd1;
        for (c=1;c<=10;c=c+1) sprite_rom[10][c]=4'd2;
        for (c=12;c<=17;c=c+1) sprite_rom[10][c]=4'd2;
        for (c=19;c<=28;c=c+1) sprite_rom[10][c]=4'd2;
    end
    //  --- Row 11-12: inter-floor white stripe ---
    begin : r1112
        integer r,c;
        for (r=11;r<=12;r=r+1) begin
            for (c=0;c<SPRITE_W;c=c+1) sprite_rom[r][c] = 4'd1;
            for (c=1;c<=10;c=c+1) sprite_rom[r][c]=4'd3;
            for (c=12;c<=17;c=c+1) sprite_rom[r][c]=4'd3;
            for (c=19;c<=28;c=c+1) sprite_rom[r][c]=4'd3;
        end
    end
    //  --- Row 13: top maroon band of 1st floor ---
    begin : r13
        integer c;
        for (c=0;c<SPRITE_W;c=c+1) sprite_rom[13][c] = 4'd1;
        for (c=1;c<=10;c=c+1) sprite_rom[13][c]=4'd2;
        for (c=12;c<=17;c=c+1) sprite_rom[13][c]=4'd2;
        for (c=19;c<=28;c=c+1) sprite_rom[13][c]=4'd2;
    end
    //  --- Rows 14-16: 1st floor windows (same pattern) ---
    begin : r1416
        integer r,c;
        for (r=14;r<=16;r=r+1) begin
            for (c=0;c<SPRITE_W;c=c+1) sprite_rom[r][c] = 4'd1;
            sprite_rom[r][1]=4'd2; sprite_rom[r][2]=4'd3;
            sprite_rom[r][3]=4'd5; sprite_rom[r][4]=4'd5;
            sprite_rom[r][5]=4'd3; sprite_rom[r][6]=4'd3;
            sprite_rom[r][7]=4'd5; sprite_rom[r][8]=4'd5;
            sprite_rom[r][9]=4'd3; sprite_rom[r][10]=4'd2;
            sprite_rom[r][12]=4'd2; sprite_rom[r][13]=4'd3;
            sprite_rom[r][14]=4'd3; sprite_rom[r][15]=4'd3;
            sprite_rom[r][16]=4'd3; sprite_rom[r][17]=4'd2;
            sprite_rom[r][19]=4'd2; sprite_rom[r][20]=4'd3;
            sprite_rom[r][21]=4'd5; sprite_rom[r][22]=4'd5;
            sprite_rom[r][23]=4'd3; sprite_rom[r][24]=4'd3;
            sprite_rom[r][25]=4'd5; sprite_rom[r][26]=4'd5;
            sprite_rom[r][27]=4'd3; sprite_rom[r][28]=4'd2;
        end
        sprite_rom[14][3]=4'd1; sprite_rom[14][4]=4'd1;
        sprite_rom[14][7]=4'd1; sprite_rom[14][8]=4'd1;
        sprite_rom[14][21]=4'd1; sprite_rom[14][22]=4'd1;
        sprite_rom[14][25]=4'd1; sprite_rom[14][26]=4'd1;
    end
    //  --- Row 17: bottom maroon band of 1st floor ---
    begin : r17
        integer c;
        for (c=0;c<SPRITE_W;c=c+1) sprite_rom[17][c] = 4'd1;
        for (c=1;c<=10;c=c+1) sprite_rom[17][c]=4'd2;
        for (c=12;c<=17;c=c+1) sprite_rom[17][c]=4'd2;
        for (c=19;c<=28;c=c+1) sprite_rom[17][c]=4'd2;
    end
    //  --- Row 18: white base strip above garage / sign ---
    begin : r18
        integer c;
        for (c=0;c<SPRITE_W;c=c+1) sprite_rom[18][c] = 4'd1;
        for (c=1;c<=28;c=c+1) sprite_rom[18][c]=4'd3;
    end
    //  --- Rows 19-22: garage + sign panel + entrance door ---
    // Cols 1-4 = garage opening (black)
    // Cols 5-24 = sign (cream) with "DRIVING SCHOOL" text implied by colour
    // Cols 25-28 = small entrance door (dark)
    begin : r1922
        integer r,c;
        for (r=19;r<=22;r=r+1) begin
            for (c=0;c<SPRITE_W;c=c+1) sprite_rom[r][c] = 4'd1;
            // left garage
            for (c=1;c<=4;c=c+1) sprite_rom[r][c]=4'd6;
            // sign panel (cream)
            for (c=5;c<=24;c=c+1) sprite_rom[r][c]=4'd9;
            // entrance arch right
            for (c=25;c<=28;c=c+1) sprite_rom[r][c]=4'd6;
        end
        // Sign outline
        sprite_rom[19][5]=4'd1; sprite_rom[19][24]=4'd1;
        sprite_rom[22][5]=4'd1; sprite_rom[22][24]=4'd1;
        for (c=5;c<=24;c=c+1) begin
            sprite_rom[19][c]=4'd1;
            sprite_rom[22][c]=4'd1;
        end
        // Re-fill sign interior (rows 20-21)
        for (r=20;r<=21;r=r+1)
            for (c=6;c<=23;c=c+1)
                sprite_rom[r][c]=4'd9;
        // Small yellow accent on sign (simulates text highlight)
        sprite_rom[20][10]=4'd1; sprite_rom[20][11]=4'd1;
        sprite_rom[20][12]=4'd1; sprite_rom[20][18]=4'd1;
        sprite_rom[20][19]=4'd1; sprite_rom[20][20]=4'd1;
        sprite_rom[21][10]=4'd1; sprite_rom[21][11]=4'd1;
        sprite_rom[21][12]=4'd1; sprite_rom[21][18]=4'd1;
        sprite_rom[21][19]=4'd1; sprite_rom[21][20]=4'd1;
    end
    //  --- Rows 23-24: front step / kerb ---
    begin : r2324
        integer c;
        for (c=0;c<SPRITE_W;c=c+1) begin
            sprite_rom[23][c]=4'd1;
            sprite_rom[24][c]=4'd1;
        end
        for (c=1;c<=28;c=c+1) sprite_rom[23][c]=4'd8;
        for (c=3;c<=26;c=c+1) sprite_rom[24][c]=4'd8;
    end
    //  --- Rows 25-26: ground / shadow ---
    begin : r2526
        integer c;
        for (c=0;c<SPRITE_W;c=c+1) begin
            sprite_rom[25][c]=4'd0;
            sprite_rom[26][c]=4'd0;
        end
        // faint shadow under building
        for (c=2;c<=27;c=c+1) sprite_rom[25][c]=4'd1;
    end
end // initial

// ── Pixel coordinate calculation (combinational) ──────────────────────────
wire signed [10:0] rel_x = $signed({1'b0,h_count}) - $signed({1'b0,x_offset});
wire signed [10:0] rel_y = $signed({1'b0,v_count}) - $signed({1'b0,y_offset});

wire in_bounds = (rel_x >= 0) && (rel_x < (SPRITE_W * SCALE)) &&
                 (rel_y >= 0) && (rel_y < (SPRITE_H * SCALE));

// Divide by SCALE (power-of-2 shift)
wire [4:0] sp_col = rel_x[($clog2(SPRITE_W * SCALE)-1):$clog2(SCALE)]; // rel_x / SCALE
wire [4:0] sp_row = rel_y[($clog2(SPRITE_H * SCALE)-1):$clog2(SCALE)]; // rel_y / SCALE

// Clamp to valid sprite index
wire [4:0] safe_col = (sp_col < SPRITE_W) ? sp_col : (SPRITE_W-1);
wire [4:0] safe_row = (sp_row < SPRITE_H) ? sp_row : (SPRITE_H-1);

// Palette lookup wires
wire [3:0] pal_idx = sprite_rom[safe_row][safe_col];

// ── Registered output ─────────────────────────────────────────────────────
always @(posedge pixel_clk) begin
    if (!in_bounds || pal_idx == 4'd0) begin
        rgb <= 12'h000;   // transparent
    end else begin
        case (pal_idx)
            4'd1:  rgb <= 12'h222;
            4'd2:  rgb <= 12'h802;
            4'd3:  rgb <= 12'hEEE;
            4'd4:  rgb <= 12'h601;
            4'd5:  rgb <= 12'hFD0;
            4'd6:  rgb <= 12'h111;
            4'd7:  rgb <= 12'h400;
            4'd8:  rgb <= 12'h888;
            4'd9:  rgb <= 12'hEDB;
            4'd10: rgb <= 12'hC00;
            default: rgb <= 12'h000;
        endcase
    end
end

endmodule