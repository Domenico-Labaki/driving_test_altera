// track_renderer.v — Pixel color determination for VGA output.
//
// Color priority (high→low):
//   Car > Cone > Finish line > Start line > Building > Track (asphalt) > Off-road (grass)
//
// Road geometry, cones, and buildings come from track_gen.v as flat buses.
// All on-track tests are simple box comparisons — no cross-products.

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
    // Sprite rows packed: row k = car_row_bus[k*22 +: 22]
    input  wire [307:0] car_row_bus,
    // Procedural track buses from track_gen
    input  wire [(`MAX_SEGS *40)-1:0]  seg_bus,
    input  wire [3:0]                  num_segs,
    input  wire [(`MAX_CONES*20)-1:0]  cone_bus,
    input  wire [3:0]                  num_cones,
    input  wire [(`MAX_BLDGS*36)-1:0]  bldg_bus,
    input  wire [3:0]                  num_bldgs,
    output reg  [23:0] rgb
);

// ── Color constants ───────────────────────────────────────────────────────
localparam C_OFFROAD1   = 24'h1FA71F; // darker grass
localparam C_OFFROAD2   = 24'h3BD93B; // lighter grass
localparam C_CONE       = 24'hFF8800;
localparam C_CAR        = 24'hFFD700;
localparam C_TRIM       = 24'hE0C070;
localparam C_WHEEL      = 24'h2F2F2F;
localparam C_BLDG       = 24'h555555;
localparam C_BLDG_OUT   = 24'h222222;
localparam C_WIN        = 24'hFFFFCC;
localparam C_START_MARK = 24'h66CCFF;
localparam C_TRACK      = 24'h282828; // dark asphalt (not pure black)
localparam C_ROAD_LINE  = 24'hFFFF00; // yellow centre-line dashes
localparam C_SKY_TOP    = 24'h9BD6F8;
localparam C_SKY_MID    = 24'h7ECFF0;
localparam C_SKY_BOTTOM = 24'h5FBEE8;
localparam C_SKY_SILH   = 24'h222222;
localparam SKY_H        = 10'd100;

// ── Trig table (Q8.8 cosine, 0–90°) for car sprite rotation ──────────────
reg signed [15:0] trig_q8 [0:90];
initial begin
    trig_q8[0]=16'sd256; trig_q8[1]=16'sd256; trig_q8[2]=16'sd256;
    trig_q8[3]=16'sd256; trig_q8[4]=16'sd255; trig_q8[5]=16'sd255;
    trig_q8[6]=16'sd255; trig_q8[7]=16'sd254; trig_q8[8]=16'sd254;
    trig_q8[9]=16'sd253; trig_q8[10]=16'sd252; trig_q8[11]=16'sd251;
    trig_q8[12]=16'sd250; trig_q8[13]=16'sd249; trig_q8[14]=16'sd248;
    trig_q8[15]=16'sd247; trig_q8[16]=16'sd246; trig_q8[17]=16'sd245;
    trig_q8[18]=16'sd243; trig_q8[19]=16'sd242; trig_q8[20]=16'sd241;
    trig_q8[21]=16'sd239; trig_q8[22]=16'sd237; trig_q8[23]=16'sd236;
    trig_q8[24]=16'sd234; trig_q8[25]=16'sd232; trig_q8[26]=16'sd230;
    trig_q8[27]=16'sd228; trig_q8[28]=16'sd226; trig_q8[29]=16'sd224;
    trig_q8[30]=16'sd222; trig_q8[31]=16'sd219; trig_q8[32]=16'sd217;
    trig_q8[33]=16'sd215; trig_q8[34]=16'sd212; trig_q8[35]=16'sd210;
    trig_q8[36]=16'sd207; trig_q8[37]=16'sd204; trig_q8[38]=16'sd202;
    trig_q8[39]=16'sd199; trig_q8[40]=16'sd196; trig_q8[41]=16'sd193;
    trig_q8[42]=16'sd190; trig_q8[43]=16'sd187; trig_q8[44]=16'sd184;
    trig_q8[45]=16'sd181; trig_q8[46]=16'sd178; trig_q8[47]=16'sd175;
    trig_q8[48]=16'sd171; trig_q8[49]=16'sd168; trig_q8[50]=16'sd165;
    trig_q8[51]=16'sd161; trig_q8[52]=16'sd158; trig_q8[53]=16'sd154;
    trig_q8[54]=16'sd150; trig_q8[55]=16'sd147; trig_q8[56]=16'sd143;
    trig_q8[57]=16'sd139; trig_q8[58]=16'sd136; trig_q8[59]=16'sd132;
    trig_q8[60]=16'sd128; trig_q8[61]=16'sd124; trig_q8[62]=16'sd120;
    trig_q8[63]=16'sd116; trig_q8[64]=16'sd112; trig_q8[65]=16'sd108;
    trig_q8[66]=16'sd104; trig_q8[67]=16'sd100; trig_q8[68]=16'sd96;
    trig_q8[69]=16'sd92;  trig_q8[70]=16'sd88;  trig_q8[71]=16'sd83;
    trig_q8[72]=16'sd79;  trig_q8[73]=16'sd75;  trig_q8[74]=16'sd71;
    trig_q8[75]=16'sd66;  trig_q8[76]=16'sd62;  trig_q8[77]=16'sd58;
    trig_q8[78]=16'sd53;  trig_q8[79]=16'sd49;  trig_q8[80]=16'sd44;
    trig_q8[81]=16'sd40;  trig_q8[82]=16'sd36;  trig_q8[83]=16'sd31;
    trig_q8[84]=16'sd27;  trig_q8[85]=16'sd22;  trig_q8[86]=16'sd18;
    trig_q8[87]=16'sd13;  trig_q8[88]=16'sd9;   trig_q8[89]=16'sd4;
    trig_q8[90]=16'sd0;
end

function signed [15:0] cos_deg_q8;
    input [8:0] ang; reg [8:0] rem;
    begin
        if      (ang < 9'd90)  begin rem=ang;         cos_deg_q8= trig_q8[rem]; end
        else if (ang < 9'd180) begin rem=ang-9'd90;   cos_deg_q8=-trig_q8[9'd90-rem]; end
        else if (ang < 9'd270) begin rem=ang-9'd180;  cos_deg_q8=-trig_q8[rem]; end
        else                   begin rem=ang-9'd270;  cos_deg_q8= trig_q8[9'd90-rem]; end
    end
endfunction
function signed [15:0] sin_deg_q8;
    input [8:0] ang; reg [8:0] rem;
    begin
        if      (ang < 9'd90)  begin rem=ang;         sin_deg_q8= trig_q8[9'd90-rem]; end
        else if (ang < 9'd180) begin rem=ang-9'd90;   sin_deg_q8= trig_q8[rem]; end
        else if (ang < 9'd270) begin rem=ang-9'd180;  sin_deg_q8=-trig_q8[9'd90-rem]; end
        else                   begin rem=ang-9'd270;  sin_deg_q8=-trig_q8[rem]; end
    end
endfunction

// ─────────────────────────────────────────────────────────────────────────
//  is_on_track — combinational; union of all road segment rectangles
//  seg_bus[i*40 +: 40] = {x1[9:0], y1[9:0], x2[9:0], y2[9:0]}
// ─────────────────────────────────────────────────────────────────────────
function [0:0] is_on_track;
    input [9:0] fpx, fpy;
    input [(`MAX_SEGS*40)-1:0] sbus;
    input [3:0] nseg;
    integer i;
    reg [9:0] sx1, sy1, sx2, sy2;
    begin
        is_on_track = 1'b0;
        for (i = 0; i < `MAX_SEGS; i = i + 1) begin
            if (i < nseg) begin
                sx1 = sbus[i*40+39 -: 10];
                sy1 = sbus[i*40+29 -: 10];
                sx2 = sbus[i*40+19 -: 10];
                sy2 = sbus[i*40+ 9 -: 10];
                if (fpx >= sx1 && fpx <= sx2 && fpy >= sy1 && fpy <= sy2)
                    is_on_track = 1'b1;
            end
        end
    end
endfunction

// ─────────────────────────────────────────────────────────────────────────
//  is_cone_pixel — diamond shape, Manhattan radius 4
//  cone_bus[i*20 +: 20] = {cx[9:0], cy[9:0]}
// ─────────────────────────────────────────────────────────────────────────
function [0:0] is_cone_pixel;
    input [9:0] fpx, fpy;
    input [(`MAX_CONES*20)-1:0] cbus;
    input [3:0] ncone;
    integer i;
    reg [10:0] dx, dy;
    reg [9:0] cx, cy;
    begin
        is_cone_pixel = 1'b0;
        for (i = 0; i < `MAX_CONES; i = i + 1) begin
            if (i < ncone) begin
                cx = cbus[i*20+19 -: 10];
                cy = cbus[i*20+ 9 -: 10];
                dx = (fpx >= cx) ? fpx - cx : cx - fpx;
                dy = (fpy >= cy) ? fpy - cy : cy - fpy;
                if (dx + dy <= 11'd4) is_cone_pixel = 1'b1;
            end
        end
    end
endfunction

// ─────────────────────────────────────────────────────────────────────────
//  bldg_color — returns building color if pixel hits a building rectangle
//  bldg_bus[i*36 +: 36] = {bx[9:0], by[9:0], bw[7:0], bh[7:0]}
//  Returns 24'h000000 as "no building" sentinel.
// ─────────────────────────────────────────────────────────────────────────
function [23:0] bldg_color;
    input [9:0] fpx, fpy;
    input [(`MAX_BLDGS*36)-1:0] bbus;
    input [3:0] nbldg;
    integer i;
    reg [9:0] bx, by;
    reg [7:0] bw, bh;
    reg hit;
    begin
        bldg_color = 24'h000000;
        hit = 1'b0;
        for (i = 0; i < `MAX_BLDGS; i = i + 1) begin
            if (!hit && i < nbldg) begin
                bx = bbus[i*36+35 -: 10];
                by = bbus[i*36+25 -: 10];
                bw = bbus[i*36+15 -:  8];
                bh = bbus[i*36+ 7 -:  8];
                if (fpx >= bx && fpx < bx + {2'b0,bw} &&
                    fpy >= by && fpy < by + {2'b0,bh}) begin
                    hit = 1'b1;
                    // 1-px outline
                    if (fpx == bx || fpx == bx+{2'b0,bw}-10'd1 ||
                        fpy == by || fpy == by+{2'b0,bh}-10'd1)
                        bldg_color = C_BLDG_OUT;
                    // Window grid: 2×2 cells on 6×8 grid, 2-px margin
                    else if (((fpx - bx - 10'd2) % 10'd6 < 10'd2) &&
                             ((fpy - by - 10'd3) % 10'd8 < 10'd2))
                        bldg_color = C_WIN;
                    else
                        bldg_color = C_BLDG;
                end
            end
        end
    end
endfunction

// ─────────────────────────────────────────────────────────────────────────
//  Car sprite functions (unchanged from original)
// ─────────────────────────────────────────────────────────────────────────
function [0:0] car_pixel;
    input [9:0] fpx, fpy, carx, cary;
    input [8:0] heading;
    input [307:0] row_bus;
    reg signed [15:0] dx, dy;
    reg signed [31:0] src_x_q8, src_y_q8;
    reg signed [15:0] src_x, src_y;
    reg [21:0] row_bits;
    begin
        car_pixel = 1'b0;
        dx = $signed({1'b0,fpx}) - $signed({1'b0,carx});
        dy = $signed({1'b0,fpy}) - $signed({1'b0,cary});
        src_x_q8 = $signed(dx)*$signed(cos_deg_q8(heading))
                 + $signed(dy)*$signed(sin_deg_q8(heading)) + 32'sd1408;
        src_y_q8 =-$signed(dx)*$signed(sin_deg_q8(heading))
                 + $signed(dy)*$signed(cos_deg_q8(heading)) + 32'sd1792;
        src_x = src_x_q8 >>> 8;
        src_y = src_y_q8 >>> 8;
        if (src_x >= 0 && src_x < 11 && src_y >= 0 && src_y < 14) begin
            row_bits = row_bus[src_y*22 +: 22];
            if (row_bits[(10 - src_x)*2 +: 2] != 2'b00)
                car_pixel = 1'b1;
        end
    end
endfunction

function [1:0] car_sprite_px;   // returns 2-bit pixel code from sprite
    input [9:0] fpx, fpy, carx, cary;
    input [8:0] heading;
    input [307:0] row_bus;
    reg signed [15:0] dx, dy;
    reg signed [31:0] src_x_q8, src_y_q8;
    reg signed [15:0] src_x, src_y;
    reg [21:0] row_bits;
    begin
        car_sprite_px = 2'b00;
        dx = $signed({1'b0,fpx}) - $signed({1'b0,carx});
        dy = $signed({1'b0,fpy}) - $signed({1'b0,cary});
        src_x_q8 = $signed(dx)*$signed(cos_deg_q8(heading))
                 + $signed(dy)*$signed(sin_deg_q8(heading)) + 32'sd1408;
        src_y_q8 =-$signed(dx)*$signed(sin_deg_q8(heading))
                 + $signed(dy)*$signed(cos_deg_q8(heading)) + 32'sd1792;
        src_x = src_x_q8 >>> 8;
        src_y = src_y_q8 >>> 8;
        if (src_x >= 0 && src_x < 11 && src_y >= 0 && src_y < 14) begin
            row_bits = row_bus[src_y*22 +: 22];
            car_sprite_px = row_bits[(10 - src_x)*2 +: 2];
        end
    end
endfunction

function [23:0] car_color;
    input [1:0] px_code;
    begin
        case (px_code)
            2'b01: car_color = 24'h880015; // dark red body
            2'b10: car_color = C_WHEEL;    // black / wheel
            2'b11: car_color = C_WIN;      // white interior
            default: car_color = C_CAR;
        endcase
    end
endfunction

// ─────────────────────────────────────────────────────────────────────────
//  Road centre-line dashes (cosmetic, every 20 px along any track segment)
// ─────────────────────────────────────────────────────────────────────────
function [0:0] is_road_dash;
    input [9:0] fpx, fpy;
    input [(`MAX_SEGS*40)-1:0] sbus;
    input [3:0] nseg;
    integer i;
    reg [9:0] sx1, sy1, sx2, sy2;
    reg [9:0] mid_x, mid_y;
    reg [9:0] seg_w, seg_h;
    begin
        is_road_dash = 1'b0;
        for (i = 0; i < `MAX_SEGS; i = i + 1) begin
            if (i < nseg) begin
                sx1 = sbus[i*40+39 -: 10];
                sy1 = sbus[i*40+29 -: 10];
                sx2 = sbus[i*40+19 -: 10];
                sy2 = sbus[i*40+ 9 -: 10];
                seg_w = sx2 - sx1;
                seg_h = sy2 - sy1;
                mid_x = sx1 + (seg_w >> 1);
                mid_y = sy1 + (seg_h >> 1);
                // Horizontal segment: dash along centre y
                if (seg_w > seg_h) begin
                    if (fpy >= mid_y-10'd1 && fpy <= mid_y+10'd1 &&
                        fpx >= sx1 && fpx <= sx2 &&
                        ((fpx - sx1) % 10'd20 < 10'd10))
                        is_road_dash = 1'b1;
                end else begin
                    // Vertical segment: dash along centre x
                    if (fpx >= mid_x-10'd1 && fpx <= mid_x+10'd1 &&
                        fpy >= sy1 && fpy <= sy2 &&
                        ((fpy - sy1) % 10'd20 < 10'd10))
                        is_road_dash = 1'b1;
                end
            end
        end
    end
endfunction

// ─────────────────────────────────────────────────────────────────────────
//  Combinational pixel classification
// ─────────────────────────────────────────────────────────────────────────
wire [1:0]  w_sprite_px  = car_sprite_px(px, py, car_x, car_y, heading_deg, car_row_bus);
wire        w_car        = (w_sprite_px != 2'b00);
wire        w_cone       = is_cone_pixel(px, py, cone_bus, num_cones);
wire        w_finish     = (py == `FINISH_LINE_Y) &&
                           (px >= `FINISH_LINE_X1) && (px <= `FINISH_LINE_X2);
wire        w_start      = (py == `START_LINE_Y) &&
                           (px >= `SF_X1) && (px <= `SF_X2);
wire        w_track      = is_on_track(px, py, seg_bus, num_segs);
wire        w_dash       = w_track & is_road_dash(px, py, seg_bus, num_segs);
wire [23:0] w_bldg       = bldg_color(px, py, bldg_bus, num_bldgs);

// ─────────────────────────────────────────────────────────────────────────
//  Registered pixel pipeline
// ─────────────────────────────────────────────────────────────────────────
always @(posedge pclk) begin
    if (!rst_n || !active) begin
        rgb <= C_SKY_TOP;
    end else begin
        // Sky band
        if (py < SKY_H) begin
            if      (py < (SKY_H/3))   rgb <= C_SKY_TOP;
            else if (py < (2*SKY_H/3)) rgb <= C_SKY_MID;
            else                        rgb <= C_SKY_BOTTOM;
        end
        // Skyline silhouette
        else if (py < SKY_H + 12 &&
                 ((px>80&&px<140)||(px>200&&px<260)||(px>330&&px<400)||(px>440&&px<520)))
            rgb <= C_SKY_SILH;
        // Car (use sprite 2-bit code for colour)
        else if (w_car)
            rgb <= car_color(w_sprite_px);
        // Cone
        else if (w_cone)
            rgb <= C_CONE;
        // Finish line — checkerboard
        else if (w_finish)
            rgb <= (px[2] ^ py[2]) ? 24'hFFFFFF : 24'h000000;
        // Start line
        else if (w_start)
            rgb <= C_START_MARK;
        // Road centre-line dashes
        else if (w_dash)
            rgb <= C_ROAD_LINE;
        // Track (asphalt)
        else if (w_track)
            rgb <= C_TRACK;
        // Building (only in off-road areas)
        else if (w_bldg != 24'h000000)
            rgb <= w_bldg;
        // Off-road: textured grass
        else
            rgb <= (px[4] ^ py[3]) ? C_OFFROAD1 : C_OFFROAD2;
    end
end

endmodule