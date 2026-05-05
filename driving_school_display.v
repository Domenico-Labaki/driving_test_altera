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

// ── Palette (4-bit per channel → 12-bit) ──────────────────────────────
//   0  transparent / off
//   1  dark red/brown outline   #A44  → 12'hA44   (was dark grey 222)
//   2  red/brown body           #C66  → 12'hC66   (was maroon 802)
//   3  white / light grey wall  #FFF  → 12'hFFF   (was EEE)
//   4  medium brown band        #A54  → 12'hA54   (was dark 601)
//   5  bright yellow window     #FF0  → 12'hFF0   (was FD0)
//   6  dark brown window/garage #553  → 12'h553   (was 111)
//   7  dark brown roof shadow   #743  → 12'h743   (was 400)
//   8  light grey step          #BBB  → 12'hBBB   (was 888)
//   9  cream door sign bg       #FDB  → 12'hFDB   (was EDB)
//  10  red accent               #F33  → 12'hF33   (was C00)
//  11  light sky fill           #9CF  → 12'h9CF   (not used in sprite; for reference)

// ── Sprite ROM — Simplified initialization ────────────────────────────────
reg [3:0] sprite_rom [0:SPRITE_H-1][0:SPRITE_W-1];

initial begin
    integer r, c;
    
    // Fill entire ROM with outline color by default
    for (r = 0; r < SPRITE_H; r = r + 1) begin
        for (c = 0; c < SPRITE_W; c = c + 1) begin
            sprite_rom[r][c] = 4'd1;
        end
    end
    
    // Top rows: roof and chimneys (mostly transparent)
    for (r = 0; r <= 3; r = r + 1)
        for (c = 0; c < SPRITE_W; c = c + 1)
            sprite_rom[r][c] = 4'd0;  // transparent fill
    
    // Now add specific roof details
    sprite_rom[0][4] = 4'd1; sprite_rom[0][5] = 4'd2; sprite_rom[0][6] = 4'd1;
    sprite_rom[0][23] = 4'd1; sprite_rom[0][24] = 4'd2; sprite_rom[0][25] = 4'd1;
    sprite_rom[1][4] = 4'd1; sprite_rom[1][5] = 4'd2; sprite_rom[1][6] = 4'd1;
    sprite_rom[1][23] = 4'd1; sprite_rom[1][24] = 4'd2; sprite_rom[1][25] = 4'd1;
    
    // Main building body: rows 4-22 initialized to palette 1 (outline)
    // Fill entire interior sections with visible colors
    for (r = 4; r <= 22; r = r + 1) begin
        for (c = 0; c < SPRITE_W; c = c + 1) begin
            if (c == 0 || c == 29)
                sprite_rom[r][c] = 4'd1;  // left/right edge outline
            else if (r >= 4 && r <= 18)
                sprite_rom[r][c] = (c >= 1 && c <= 28) ? 4'd3 : 4'd1;  // white fill with outlines
            else
                sprite_rom[r][c] = 4'd1;  // default outline
        end
    end
    
    // Rows 4-6: roof bands and cornice
    for (r = 4; r <= 6; r = r + 1) begin
        for (c = 1; c <= 10; c = c + 1) sprite_rom[r][c] = 4'd4;
        for (c = 12; c <= 17; c = c + 1) sprite_rom[r][c] = 4'd4;
        for (c = 19; c <= 28; c = c + 1) sprite_rom[r][c] = 4'd4;
    end
    
    // Rows 5: white stripe (cornice)
    for (c = 1; c <= 10; c = c + 1) sprite_rom[5][c] = 4'd3;
    for (c = 12; c <= 17; c = c + 1) sprite_rom[5][c] = 4'd3;
    for (c = 19; c <= 28; c = c + 1) sprite_rom[5][c] = 4'd3;
    
    // Rows 7-9: walls with white
    for (r = 7; r <= 9; r = r + 1) begin
        for (c = 1; c <= 10; c = c + 1) sprite_rom[r][c] = 4'd3;
        for (c = 12; c <= 17; c = c + 1) sprite_rom[r][c] = 4'd3;
        for (c = 19; c <= 28; c = c + 1) sprite_rom[r][c] = 4'd3;
    end
    
    // Rows 10-18: alternating red/brown and white floors
    for (r = 10; r <= 18; r = r + 1) begin
        for (c = 1; c <= 10; c = c + 1) sprite_rom[r][c] = 4'd3;
        for (c = 12; c <= 17; c = c + 1) sprite_rom[r][c] = 4'd3;
        for (c = 19; c <= 28; c = c + 1) sprite_rom[r][c] = 4'd3;
    end
    
    // Rows 19-22: garage and sign
    for (r = 19; r <= 22; r = r + 1) begin
        for (c = 1; c <= 4; c = c + 1) sprite_rom[r][c] = 4'd6;   // garage door (dark)
        for (c = 5; c <= 24; c = c + 1) sprite_rom[r][c] = 4'd9;  // sign (cream)
        for (c = 25; c <= 28; c = c + 1) sprite_rom[r][c] = 4'd6; // entrance (dark)
    end
    
    // Rows 23-24: step
    for (r = 23; r <= 24; r = r + 1)
        for (c = 1; c <= 28; c = c + 1)
            sprite_rom[r][c] = 4'd8;  // grey step
    
    // Rows 25-26: ground shadow (transparent)
    for (r = 25; r <= 26; r = r + 1)
        for (c = 0; c < SPRITE_W; c = c + 1)
            sprite_rom[r][c] = 4'd0;
end

// ── Pixel coordinate calculation (combinational) ──────────────────────────
wire signed [10:0] rel_x = $signed({1'b0,h_count}) - $signed({1'b0,x_offset});
wire signed [10:0] rel_y = $signed({1'b0,v_count}) - $signed({1'b0,y_offset});

wire in_bounds = (rel_x >= 0) && (rel_x < (SPRITE_W * SCALE)) &&
                 (rel_y >= 0) && (rel_y < (SPRITE_H * SCALE));

// Divide by SCALE (power-of-2 shift)
wire [4:0] sp_col = rel_x[($clog2(SPRITE_W * SCALE)-1):$clog2(SCALE)];
wire [4:0] sp_row = rel_y[($clog2(SPRITE_H * SCALE)-1):$clog2(SCALE)];

// Clamp to valid sprite index
wire [4:0] safe_col = (sp_col < SPRITE_W) ? sp_col : (SPRITE_W-1);
wire [4:0] safe_row = (sp_row < SPRITE_H) ? sp_row : (SPRITE_H-1);

// Palette lookup wires
wire [3:0] pal_idx = sprite_rom[safe_row][safe_col];

// ── Combinational output (not registered) ────────────────────────────────
always @(*) begin
    if (!in_bounds || pal_idx == 4'd0) begin
        rgb = 12'h000;   // transparent
    end else begin
        case (pal_idx)
            4'd1:  rgb = 12'hA44;  // dark red/brown outline
            4'd2:  rgb = 12'hC66;  // red/brown body
            4'd3:  rgb = 12'hFFF;  // white walls
            4'd4:  rgb = 12'hA54;  // medium brown band
            4'd5:  rgb = 12'hFF0;  // bright yellow window
            4'd6:  rgb = 12'h553;  // dark brown window/garage
            4'd7:  rgb = 12'h743;  // dark roof shadow
            4'd8:  rgb = 12'hBBB;  // light grey step
            4'd9:  rgb = 12'hFDB;  // cream sign background
            4'd10: rgb = 12'hF33;  // red accent
            default: rgb = 12'h000;
        endcase
    end
end

endmodule
