// track_renderer.v — Pixel color determination for VGA output.
//
// Color priority (high→low):
//   Car (yellow) > Cone (orange) > SF line (white) > Building > Track (black) > Off-road (green)
//
// The is_on_track function encodes the DXF boundary geometry from track_data.vh.
// All arithmetic is integer; no floating point.

`include "track_data.vh"

module track_renderer (
    input  wire        pclk,
    input  wire        rst_n,
    input  wire        active,
    input  wire [9:0]  px,
    input  wire [9:0]  py,
    // Car
    input  wire [9:0]  car_x,
    input  wire [9:0]  car_y,
    input  wire [2:0]  car_angle,
    input  wire [8:0]  heading_deg,
    // Sprite rows packed: row k = car_row_bus[k*14 +: 14]
    input  wire [111:0] car_row_bus,
    output reg  [23:0] rgb
);

// ── Color constants ───────────────────────────────────────────────────────
localparam C_OFFROAD1 = 24'h1FA71F; // darker grass
localparam C_OFFROAD2 = 24'h3BD93B; // lighter grass
localparam C_CONE     = 24'hFF8800;
localparam C_CAR      = 24'hFFD700; // warmer gold (default body)
localparam C_TRIM     = 24'hE0C070; // trim/roof highlight
localparam C_WHEEL    = 24'h2F2F2F; // dark wheel color
localparam C_BLDG     = 24'h555555;
localparam C_BLDG_OUT = 24'h222222;
localparam C_WIN      = 24'hFFFFCC; // slightly warm window
localparam C_START_MARK  = 24'h66CCFF;
localparam C_FINISH_MARK = 24'hFFFFFF;
localparam C_SKY_TOP    = 24'h9BD6F8; // lighter top sky
localparam C_SKY_MID    = 24'h7ECFF0;
localparam C_SKY_BOTTOM = 24'h5FBEE8; // near horizon
localparam C_SKY_SILH   = 24'h222222; // skyline silhouette
localparam C_TRACK    = 24'h000000;
localparam SKY_H = 10'd80; // sky height in pixels

// 0..90 degree Q8.8 cosine table, reused for sine via quadrant symmetry.
reg signed [15:0] trig_q8 [0:90];

initial begin
    trig_q8[0]  = 16'sd256; trig_q8[1]  = 16'sd256; trig_q8[2]  = 16'sd256;
    trig_q8[3]  = 16'sd256; trig_q8[4]  = 16'sd255; trig_q8[5]  = 16'sd255;
    trig_q8[6]  = 16'sd255; trig_q8[7]  = 16'sd254; trig_q8[8]  = 16'sd254;
    trig_q8[9]  = 16'sd253; trig_q8[10] = 16'sd252; trig_q8[11] = 16'sd251;
    trig_q8[12] = 16'sd250; trig_q8[13] = 16'sd249; trig_q8[14] = 16'sd248;
    trig_q8[15] = 16'sd247; trig_q8[16] = 16'sd246; trig_q8[17] = 16'sd245;
    trig_q8[18] = 16'sd243; trig_q8[19] = 16'sd242; trig_q8[20] = 16'sd241;
    trig_q8[21] = 16'sd239; trig_q8[22] = 16'sd237; trig_q8[23] = 16'sd236;
    trig_q8[24] = 16'sd234; trig_q8[25] = 16'sd232; trig_q8[26] = 16'sd230;
    trig_q8[27] = 16'sd228; trig_q8[28] = 16'sd226; trig_q8[29] = 16'sd224;
    trig_q8[30] = 16'sd222; trig_q8[31] = 16'sd219; trig_q8[32] = 16'sd217;
    trig_q8[33] = 16'sd215; trig_q8[34] = 16'sd212; trig_q8[35] = 16'sd210;
    trig_q8[36] = 16'sd207; trig_q8[37] = 16'sd204; trig_q8[38] = 16'sd202;
    trig_q8[39] = 16'sd199; trig_q8[40] = 16'sd196; trig_q8[41] = 16'sd193;
    trig_q8[42] = 16'sd190; trig_q8[43] = 16'sd187; trig_q8[44] = 16'sd184;
    trig_q8[45] = 16'sd181; trig_q8[46] = 16'sd178; trig_q8[47] = 16'sd175;
    trig_q8[48] = 16'sd171; trig_q8[49] = 16'sd168; trig_q8[50] = 16'sd165;
    trig_q8[51] = 16'sd161; trig_q8[52] = 16'sd158; trig_q8[53] = 16'sd154;
    trig_q8[54] = 16'sd150; trig_q8[55] = 16'sd147; trig_q8[56] = 16'sd143;
    trig_q8[57] = 16'sd139; trig_q8[58] = 16'sd136; trig_q8[59] = 16'sd132;
    trig_q8[60] = 16'sd128; trig_q8[61] = 16'sd124; trig_q8[62] = 16'sd120;
    trig_q8[63] = 16'sd116; trig_q8[64] = 16'sd112; trig_q8[65] = 16'sd108;
    trig_q8[66] = 16'sd104; trig_q8[67] = 16'sd100; trig_q8[68] = 16'sd96;
    trig_q8[69] = 16'sd92;  trig_q8[70] = 16'sd88;  trig_q8[71] = 16'sd83;
    trig_q8[72] = 16'sd79;  trig_q8[73] = 16'sd75;  trig_q8[74] = 16'sd71;
    trig_q8[75] = 16'sd66;  trig_q8[76] = 16'sd62;  trig_q8[77] = 16'sd58;
    trig_q8[78] = 16'sd53;  trig_q8[79] = 16'sd49;  trig_q8[80] = 16'sd44;
    trig_q8[81] = 16'sd40;  trig_q8[82] = 16'sd36;  trig_q8[83] = 16'sd31;
    trig_q8[84] = 16'sd27;  trig_q8[85] = 16'sd22;  trig_q8[86] = 16'sd18;
    trig_q8[87] = 16'sd13;  trig_q8[88] = 16'sd9;   trig_q8[89] = 16'sd4;
    trig_q8[90] = 16'sd0;
end

function signed [15:0] cos_deg_q8;
    input [8:0] ang;
    reg [8:0] rem;
    begin
        if (ang < 9'd90) begin
            rem = ang;
            cos_deg_q8 = trig_q8[rem];
        end else if (ang < 9'd180) begin
            rem = ang - 9'd90;
            cos_deg_q8 = -trig_q8[9'd90 - rem];
        end else if (ang < 9'd270) begin
            rem = ang - 9'd180;
            cos_deg_q8 = -trig_q8[rem];
        end else begin
            rem = ang - 9'd270;
            cos_deg_q8 = trig_q8[9'd90 - rem];
        end
    end
endfunction

function signed [15:0] sin_deg_q8;
    input [8:0] ang;
    reg [8:0] rem;
    begin
        if (ang < 9'd90) begin
            rem = ang;
            sin_deg_q8 = trig_q8[9'd90 - rem];
        end else if (ang < 9'd180) begin
            rem = ang - 9'd90;
            sin_deg_q8 = trig_q8[rem];
        end else if (ang < 9'd270) begin
            rem = ang - 9'd180;
            sin_deg_q8 = -trig_q8[9'd90 - rem];
        end else begin
            rem = ang - 9'd270;
            sin_deg_q8 = -trig_q8[rem];
        end
    end
endfunction

// ─────────────────────────────────────────────────────────────────────────
//  is_on_track — pure combinational; returns 1 when pixel is drivable road
// ─────────────────────────────────────────────────────────────────────────
function [0:0] is_on_track;
    input [9:0] fpx, fpy;
    reg signed [20:0] cross2, cross3, cross4;
    reg in_inner;
    begin
        is_on_track = 1'b0;

        // Outer boundary
        if (fpx < `OUTER_LEFT  || fpx > `OUTER_RIGHT ||
            fpy < `OUTER_TOP   || fpy > `OUTER_BOTTOM) begin
            is_on_track = 1'b0;

        // Top-right rounded corner: off-track when (px-590)*38 > (58-py)*30
        end else if (fpx > `TR_CORNER_X && fpy < `TR_CORNER_Y) begin
            if (($unsigned(fpx) - 10'd590) * 10'd38 <=
                (10'd58 - $unsigned(fpy)) * 10'd30)
                is_on_track = 1'b1;

        // Bottom-right rounded corner: off-track when (px-581)*30 < (py-350)*39
        end else if (fpx > `BR_CORNER_X && fpy > `BR_CORNER_Y) begin
            if (($unsigned(fpx) - 10'd581) * 10'd30 >=
                ($unsigned(fpy) - 10'd350) * 10'd39)
                is_on_track = 1'b1;

        end else begin
            in_inner = 1'b0;

            // ── V-notch island (entities 1–4) ─────────────────────────
            // Polygon: (29,91)→(186,91)→(83,178)→(117,219)→(274,91)
            if (fpy >= `INNER_TL_Y && fpx >= `INNER_TL_X1 && fpx <= `ISLAND_TOP_X1) begin
                // Entity 2: (186,91)→(83,178): cross = -103*(py-91) - 87*(px-186)
                cross2 = -21'sd103 * $signed({1'b0, fpy} - 10'd91)
                         - 21'sd87  * $signed({1'b0, fpx} - 10'd186);
                // Entity 3: (83,178)→(117,219): cross = 34*(py-178) - 41*(px-83)
                cross3 = 21'sd34 * $signed({1'b0, fpy} - 10'd178)
                         - 21'sd41 * $signed({1'b0, fpx} - 10'd83);
                // Entity 4: (117,219)→(274,91): cross = 157*(py-219)+128*(px-117)
                cross4 = 21'sd157 * $signed({1'b0, fpy} - 10'd219)
                         + 21'sd128 * $signed({1'b0, fpx} - 10'd117);

                if (fpy <= `E2_Y2) begin
                    // Above entity-3 start: island left of entity-2
                    if (cross2 < 21'sd0) in_inner = 1'b1;
                end else if (fpy <= `E3_Y2) begin
                    // Entity-3 zone: inside when both cross3<0 and cross4<0
                    if (cross3 < 21'sd0 && cross4 < 21'sd0) in_inner = 1'b1;
                end
            end

            // ── Main right island [274..543]×[90..314] ─────────────────
            if (fpx >= `ISLAND_BX1 && fpx <= `ISLAND_BX2 &&
                fpy >= `ISLAND_BY1 && fpy <= `ISLAND_BY2) begin

                // Staircase pocket on right side — this is ON-TRACK
                if (fpx >= `STEP_CUTOUT_X1 && fpx <= `STEP_CUTOUT_X2 &&
                    fpy >= `STEP_CUTOUT_Y1 && fpy <= `STEP_CUTOUT_Y2) begin
                    // Track — do nothing
                end
                // Lower-right step extension — OFF-TRACK
                else if (fpx >= `STEP_LR_X1 && fpx <= `STEP_LR_X2 &&
                         fpy >= `STEP_LR_Y1 && fpy <= `STEP_LR_Y2) begin
                    in_inner = 1'b1;
                end
                // Left wall portion (x≥318, y≥103)
                else if (fpx >= `ISLAND_LEFT_X && fpy >= `ISLAND_LEFT_Y1) begin
                    in_inner = 1'b1;
                end
                // Top strip (x<318, y in [90,103))
                else if (fpx < `ISLAND_LEFT_X && fpy < `ISLAND_LEFT_Y1) begin
                    in_inner = 1'b1;
                end
            end

            // ── Bottom-left shelf [103..237]×[260..319] ────────────────
            if (fpx >= `BOT_LEFT_X1 && fpx <= `BOT_LEFT_X2 &&
                fpy >= `BOT_LEFT_Y1 && fpy <= `BOT_LEFT_Y2)
                in_inner = 1'b1;

            // ── Bottom mid [237..507]×[319..314] ───────────────────────
            if (fpx >= `BOT_LEFT_X2 && fpx <= `BOT_EXT_X1 &&
                fpy >= `BOT_INNER_Y && fpy <= `ISLAND_BY2)
                in_inner = 1'b1;

            // ── Bottom-right extension [507..543]×[314..319] ───────────
            if (fpx >= `BOT_EXT_X1 && fpx <= `BOT_EXT_X2 &&
                fpy >= `BOT_EXT_Y1 && fpy <= `BOT_EXT_Y2)
                in_inner = 1'b1;

            is_on_track = ~in_inner;
        end
    end
endfunction

// ─────────────────────────────────────────────────────────────────────────
//  Cone pixel: diamond shape, radius 3
// ─────────────────────────────────────────────────────────────────────────
function [0:0] is_cone_pixel;
    input [9:0] fpx, fpy;
    reg [10:0] dx, dy;
    // All 10 cone checks expanded (no loop — loop-carried arrays don't synthesize)
    begin
        is_cone_pixel = 1'b0;
        // Cone 0: (108,135)
        dx = (fpx>=10'd108) ? fpx-10'd108 : 10'd108-fpx;
        dy = (fpy>=10'd135) ? fpy-10'd135 : 10'd135-fpy;
        if (dx+dy <= 11'd3) is_cone_pixel = 1'b1;
        // Cone 1: (83,178)
        dx = (fpx>=10'd83)  ? fpx-10'd83  : 10'd83-fpx;
        dy = (fpy>=10'd178) ? fpy-10'd178 : 10'd178-fpy;
        if (dx+dy <= 11'd3) is_cone_pixel = 1'b1;
        // Cone 2: (117,219)
        dx = (fpx>=10'd117) ? fpx-10'd117 : 10'd117-fpx;
        dy = (fpy>=10'd219) ? fpy-10'd219 : 10'd219-fpy;
        if (dx+dy <= 11'd3) is_cone_pixel = 1'b1;
        // Cone 3: (210,91)
        dx = (fpx>=10'd210) ? fpx-10'd210 : 10'd210-fpx;
        dy = (fpy>=10'd91)  ? fpy-10'd91  : 10'd91-fpy;
        if (dx+dy <= 11'd3) is_cone_pixel = 1'b1;
        // Cone 4: (400,55)
        dx = (fpx>=10'd400) ? fpx-10'd400 : 10'd400-fpx;
        dy = (fpy>=10'd55)  ? fpy-10'd55  : 10'd55-fpy;
        if (dx+dy <= 11'd3) is_cone_pixel = 1'b1;
        // Cone 5: (580,135)
        dx = (fpx>=10'd580) ? fpx-10'd580 : 10'd580-fpx;
        dy = (fpy>=10'd135) ? fpy-10'd135 : 10'd135-fpy;
        if (dx+dy <= 11'd3) is_cone_pixel = 1'b1;
        // Cone 6: (580,320)
        dx = (fpx>=10'd580) ? fpx-10'd580 : 10'd580-fpx;
        dy = (fpy>=10'd320) ? fpy-10'd320 : 10'd320-fpy;
        if (dx+dy <= 11'd3) is_cone_pixel = 1'b1;
        // Cone 7: (420,350)
        dx = (fpx>=10'd420) ? fpx-10'd420 : 10'd420-fpx;
        dy = (fpy>=10'd350) ? fpy-10'd350 : 10'd350-fpy;
        if (dx+dy <= 11'd3) is_cone_pixel = 1'b1;
        // Cone 8: (170,350)
        dx = (fpx>=10'd170) ? fpx-10'd170 : 10'd170-fpx;
        dy = (fpy>=10'd350) ? fpy-10'd350 : 10'd350-fpy;
        if (dx+dy <= 11'd3) is_cone_pixel = 1'b1;
        // Cone 9: (50,260)
        dx = (fpx>=10'd50)  ? fpx-10'd50  : 10'd50-fpx;
        dy = (fpy>=10'd260) ? fpy-10'd260 : 10'd260-fpy;
        if (dx+dy <= 11'd3) is_cone_pixel = 1'b1;
    end
endfunction

// ─────────────────────────────────────────────────────────────────────────
//  Car sprite pixel
// ─────────────────────────────────────────────────────────────────────────
function [0:0] car_pixel;
    input [9:0] fpx, fpy, carx, cary;
    input [8:0] heading;
    input [111:0] row_bus;
    reg signed [15:0] dx, dy;
    reg signed [31:0] src_x_q8, src_y_q8;
    reg signed [15:0] src_x, src_y;
    reg [13:0] row_bits;
    begin
        car_pixel = 1'b0;
        dx = $signed({1'b0, fpx}) - $signed({1'b0, carx});
        dy = $signed({1'b0, fpy}) - $signed({1'b0, cary});
        src_x_q8 = $signed(dx) * $signed(cos_deg_q8(heading)) +
                   $signed(dy) * $signed(sin_deg_q8(heading)) + 32'sd1664;
        src_y_q8 = -$signed(dx) * $signed(sin_deg_q8(heading)) +
                    $signed(dy) * $signed(cos_deg_q8(heading)) + 32'sd896;
        src_x = src_x_q8 >>> 8;
        src_y = src_y_q8 >>> 8;
        if (src_x >= 0 && src_x < 14 && src_y >= 0 && src_y < 8) begin
            row_bits = row_bus[src_y * 14 +: 14];
            car_pixel = row_bits[13 - src_x];
        end
    end
endfunction

// Highlight windows / detailing on the car: returns 1 for window pixels.
function [0:0] car_window;
    input [9:0] fpx, fpy, carx, cary;
    input [8:0] heading;
    input [111:0] row_bus;
    reg signed [15:0] dx, dy;
    reg signed [31:0] src_x_q8, src_y_q8;
    reg signed [15:0] src_x, src_y;
    reg [13:0] row_bits;
    begin
        car_window = 1'b0;
        dx = $signed({1'b0, fpx}) - $signed({1'b0, carx});
        dy = $signed({1'b0, fpy}) - $signed({1'b0, cary});
        src_x_q8 = $signed(dx) * $signed(cos_deg_q8(heading)) +
                   $signed(dy) * $signed(sin_deg_q8(heading)) + 32'sd1664;
        src_y_q8 = -$signed(dx) * $signed(sin_deg_q8(heading)) +
                    $signed(dy) * $signed(cos_deg_q8(heading)) + 32'sd896;
        src_x = src_x_q8 >>> 8;
        src_y = src_y_q8 >>> 8;
        if (src_x >= 0 && src_x < 14 && src_y >= 0 && src_y < 8) begin
            row_bits = row_bus[src_y * 14 +: 14];
            if (row_bits[13 - src_x]) begin
                // Use src_x bands for vertical layering so the window stays on top.
                if ((src_x >= 3 && src_x <= 6) && (src_y >= 1 && src_y <= 6))
                    car_window = 1'b1;
            end
        end
    end
endfunction

// Per-pixel car color chooser: returns a color depending on relative pixel in sprite
function [23:0] car_color;
    input [9:0] fpx, fpy, carx, cary;
    input [8:0] heading;
    input [111:0] row_bus;
    reg signed [15:0] dx, dy;
    reg signed [31:0] src_x_q8, src_y_q8;
    reg signed [15:0] src_x, src_y;
    reg [13:0] row_bits;
    begin
        car_color = C_CAR;
        dx = $signed({1'b0, fpx}) - $signed({1'b0, carx});
        dy = $signed({1'b0, fpy}) - $signed({1'b0, cary});
        src_x_q8 = $signed(dx) * $signed(cos_deg_q8(heading)) +
                   $signed(dy) * $signed(sin_deg_q8(heading)) + 32'sd1664;
        src_y_q8 = -$signed(dx) * $signed(sin_deg_q8(heading)) +
                    $signed(dy) * $signed(cos_deg_q8(heading)) + 32'sd896;
        src_x = src_x_q8 >>> 8;
        src_y = src_y_q8 >>> 8;
        if (src_x >= 0 && src_x < 14 && src_y >= 0 && src_y < 8) begin
            row_bits = row_bus[src_y * 14 +: 14];
            if (row_bits[13 - src_x]) begin
                // Bottom of the car is dark (wheels/undercarriage).
                if (src_x >= 11)
                    car_color = C_WHEEL;
                else if (src_y <= 1 || src_y >= 6 || (src_x >= 4 && src_x <= 9 && src_y >= 2 && src_y <= 4))
                    car_color = C_TRIM;
                else
                    car_color = C_CAR;
            end
        end
    end
endfunction

// ─────────────────────────────────────────────────────────────────────────
//  Building color — returns non-zero color if pixel is inside a building
//  (returns 24'h000000 = C_TRACK as "no building" sentinel)
// ─────────────────────────────────────────────────────────────────────────
// Building table: {bx[9:0], by[9:0], bw[6:0], bh[6:0]} per building
// Packed as 36-bit entries
function [23:0] bldg_color;
    input [9:0] fpx, fpy;
    // Building data: x, y, w, h
    reg [9:0] bx, by;
    reg [6:0] bw, bh;
    reg hit;
    reg [3:0] widx, hidx;
    begin
        bldg_color = 24'h000000;
        hit = 1'b0;

        // Building 0: x=300,y=105,w=32,h=40
        if (!hit && fpx>=300 && fpx<332 && fpy>=105 && fpy<145) begin
            hit=1; bx=300; by=105; bw=32; bh=40; end
        // Building 1: x=360,y=115,w=24,h=30
        if (!hit && fpx>=360 && fpx<384 && fpy>=115 && fpy<145) begin
            hit=1; bx=360; by=115; bw=24; bh=30; end
        // Building 2: x=410,y=108,w=20,h=50
        if (!hit && fpx>=410 && fpx<430 && fpy>=108 && fpy<158) begin
            hit=1; bx=410; by=108; bw=20; bh=50; end
        // Building 3: x=340,y=200,w=40,h=60
        if (!hit && fpx>=340 && fpx<380 && fpy>=200 && fpy<260) begin
            hit=1; bx=340; by=200; bw=40; bh=60; end
        // Building 4: x=300,y=210,w=28,h=45
        if (!hit && fpx>=300 && fpx<328 && fpy>=210 && fpy<255) begin
            hit=1; bx=300; by=210; bw=28; bh=45; end
        // Building 5: x=460,y=180,w=36,h=80
        if (!hit && fpx>=460 && fpx<496 && fpy>=180 && fpy<260) begin
            hit=1; bx=460; by=180; bw=36; bh=80; end
        // Building 6: x=150,y=300,w=30,h=35
        if (!hit && fpx>=150 && fpx<180 && fpy>=300 && fpy<335) begin
            hit=1; bx=150; by=300; bw=30; bh=35; end
        // Building 7: x=350,y=330,w=40,h=28
        if (!hit && fpx>=350 && fpx<390 && fpy>=330 && fpy<358) begin
            hit=1; bx=350; by=330; bw=40; bh=28; end

        if (hit) begin
            // Outline (1-px border)
            if (fpx == bx || fpx == bx+{3'b0,bw}-10'd1 ||
                fpy == by || fpy == by+{3'b0,bh}-10'd1)
                bldg_color = C_BLDG_OUT;
            // Windows: 2×2 bright yellow on 6×8 grid with 2-px margin
            else if (((fpx - bx - 10'd2) % 10'd6 < 10'd2) &&
                     ((fpy - by - 10'd3) % 10'd8 < 10'd2))
                bldg_color = C_WIN;
            else
                bldg_color = C_BLDG;
        end
    end
endfunction

// ─────────────────────────────────────────────────────────────────────────
//  Combinational wires
// ─────────────────────────────────────────────────────────────────────────
wire        w_car   = car_pixel(px, py, car_x, car_y, heading_deg, car_row_bus);
wire        w_car_win = car_window(px, py, car_x, car_y, heading_deg, car_row_bus);
wire        w_cone  = is_cone_pixel(px, py);
wire        w_start  = (py == `START_LINE_Y)  && (px >= `SF_X1) && (px <= `SF_X2);
wire        w_finish = (py == `FINISH_LINE_Y) && (px >= `SF_X1) && (px <= `SF_X2);
wire        w_track = is_on_track(px, py);
wire [23:0] w_bldg  = bldg_color(px, py);

// ─────────────────────────────────────────────────────────────────────────
//  Registered pixel pipeline
// ─────────────────────────────────────────────────────────────────────────
always @(posedge pclk) begin
    if (!rst_n || !active) begin
        // show a pale sky while inactive
        rgb <= C_SKY_TOP;
    end else begin
        // Sky gradient band at top
        if (py < SKY_H) begin
            // interpolate between top/mid/bottom roughly by thirds
            if (py < (SKY_H/3)) rgb <= C_SKY_TOP;
            else if (py < (2*SKY_H/3)) rgb <= C_SKY_MID;
            else rgb <= C_SKY_BOTTOM;
        end
        // Skyline silhouette (simple blocks) just below gradient
        else if (py >= SKY_H && py < SKY_H + 10 && ( (px>80 && px<140) || (px>180 && px<240) || (px>300 && px<360) || (px>400 && px<480) ) ) begin
            rgb <= C_SKY_SILH;
        end
        else if (w_car_win)
            rgb <= C_WIN;
        else if (w_car)
            rgb <= car_color(px, py, car_x, car_y, heading_deg, car_row_bus);
        else if (w_cone)
            rgb <= C_CONE;
        else if (w_finish)
            rgb <= C_FINISH_MARK;
        else if (w_start)
            rgb <= C_START_MARK;
        else if (w_bldg != 24'h000000 && !w_track)
            rgb <= w_bldg;
        else if (w_track)
            rgb <= C_TRACK;
        else
            // Textured grass: pick between two greens based on simple spatial pattern
            rgb <= (px[4] ^ py[3]) ? C_OFFROAD1 : C_OFFROAD2;
    end
end

endmodule
