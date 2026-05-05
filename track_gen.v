// track_gen.v — Procedural track generator for GEL372 Driving Test.
//
// On every reset the module uses a free-running 16-bit LFSR to pick one of
// four hand-crafted rectangular-segment track layouts.  All road geometry is
// axis-aligned rectangles so the on-track test is pure box comparisons.
//
// Bus packing:
//   seg_bus  : MAX_SEGS  × 40 bits  [i*40 +: 40] = {x1[9:0],y1[9:0],x2[9:0],y2[9:0]}
//   cone_bus : MAX_CONES × 20 bits  [i*20 +: 20] = {cx[9:0],cy[9:0]}
//   bldg_bus : MAX_BLDGS × 36 bits  [i*36 +: 36] = {bx[9:0],by[9:0],bw[7:0],bh[7:0]}
//   coin_bus : MAX_COINS × 20 bits  [i*20 +: 20] = {cx[9:0],cy[9:0]}
//
// All coin positions lie inside a road segment rectangle.

`include "track_data.vh"

module track_gen (
    input  wire        clk50,
    input  wire        rst_n,
    // Road segments
    output reg  [(`MAX_SEGS*40)-1:0]  seg_bus,
    output reg  [3:0]                  num_segs,
    // Cones
    output reg  [(`MAX_CONES*20)-1:0]  cone_bus,
    output reg  [3:0]                  num_cones,
    // Buildings
    output reg  [(`MAX_BLDGS*36)-1:0]  bldg_bus,
    output reg  [3:0]                  num_bldgs,
    // Coins
    output reg  [(`MAX_COINS*20)-1:0]  coin_bus,
    output reg  [3:0]                  num_coins
);

// temporaries for procedural mirroring / grass placement
integer i, gi;
reg [(`MAX_SEGS*40)-1:0] new_seg_bus;
reg [(`MAX_BLDGS*36)-1:0] new_bldg_bus;
reg [9:0] sx1,sy1,sx2,sy2;
reg [9:0] cx,cy;
reg [9:0] bx,by,nbx,gbx,gby;
reg [7:0] bw,bh,gbw,gbh;

// ── Free-running LFSR (16-bit Fibonacci, taps 16,15,13,4) ────────────────
reg [15:0] lfsr;
always @(posedge clk50)
    lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[14] ^ lfsr[12] ^ lfsr[3]};

// ── Reset rising-edge detector ────────────────────────────────────────────
reg rst_prev;
always @(posedge clk50) rst_prev <= rst_n;
wire load_track = rst_n & ~rst_prev;

// ── Layout load ───────────────────────────────────────────────────────────
always @(posedge clk50) begin
    if (load_track) begin
        seg_bus  <= 0;
        cone_bus <= 0;
        bldg_bus <= 0;
        coin_bus <= 0;

        case (lfsr[1:0])

            // ═══════════════════════════════════════════════════════════════
            // LAYOUT 0 — clockwise outer loop with inner detour
            // ═══════════════════════════════════════════════════════════════
            2'd0: begin
                num_segs  <= 4'd10;
                num_cones <= 4'd8;
                num_bldgs <= 4'd6;
                num_coins <= 4'd12;

                // Road segments
                seg_bus[0*40 +: 40] <= {10'd20,  10'd130, 10'd70,  10'd400};
                seg_bus[1*40 +: 40] <= {10'd20,  10'd130, 10'd590, 10'd180};
                seg_bus[2*40 +: 40] <= {10'd540, 10'd130, 10'd590, 10'd400};
                seg_bus[3*40 +: 40] <= {10'd20,  10'd350, 10'd590, 10'd400};
                seg_bus[4*40 +: 40] <= {10'd200, 10'd220, 10'd500, 10'd270};
                seg_bus[5*40 +: 40] <= {10'd450, 10'd180, 10'd500, 10'd270};
                seg_bus[6*40 +: 40] <= {10'd200, 10'd180, 10'd250, 10'd270};
                seg_bus[7*40 +: 40] <= {10'd200, 10'd270, 10'd500, 10'd320};
                seg_bus[8*40 +: 40] <= {10'd70,  10'd180, 10'd250, 10'd230};
                seg_bus[9*40 +: 40] <= {10'd70,  10'd320, 10'd250, 10'd370};

                // Cones
                cone_bus[0*20 +: 20] <= {10'd70,  10'd155};
                cone_bus[1*20 +: 20] <= {10'd565, 10'd155};
                cone_bus[2*20 +: 20] <= {10'd565, 10'd375};
                cone_bus[3*20 +: 20] <= {10'd70,  10'd375};
                cone_bus[4*20 +: 20] <= {10'd225, 10'd205};
                cone_bus[5*20 +: 20] <= {10'd475, 10'd205};
                cone_bus[6*20 +: 20] <= {10'd475, 10'd295};
                cone_bus[7*20 +: 20] <= {10'd225, 10'd295};

                // Buildings
                bldg_bus[0*36 +: 36] <= {10'd100, 10'd150, 8'd80, 8'd90};
                bldg_bus[1*36 +: 36] <= {10'd250, 10'd150, 8'd80, 8'd90};
                bldg_bus[2*36 +: 36] <= {10'd400, 10'd150, 8'd80, 8'd90};
                bldg_bus[3*36 +: 36] <= {10'd100, 10'd290, 8'd70, 8'd40};
                bldg_bus[4*36 +: 36] <= {10'd280, 10'd290, 8'd60, 8'd40};
                bldg_bus[5*36 +: 36] <= {10'd370, 10'd290, 8'd60, 8'd40};

                // Coins — on road, clear of cones
                coin_bus[ 0*20 +: 20] <= {10'd45,  10'd200}; // left corridor
                coin_bus[ 1*20 +: 20] <= {10'd45,  10'd310}; // left corridor lower
                coin_bus[ 2*20 +: 20] <= {10'd150, 10'd155}; // top strip
                coin_bus[ 3*20 +: 20] <= {10'd300, 10'd155}; // top strip mid
                coin_bus[ 4*20 +: 20] <= {10'd440, 10'd155}; // top strip right
                coin_bus[ 5*20 +: 20] <= {10'd565, 10'd250}; // right corridor
                coin_bus[ 6*20 +: 20] <= {10'd440, 10'd375}; // bottom strip
                coin_bus[ 7*20 +: 20] <= {10'd300, 10'd375}; // bottom strip mid
                coin_bus[ 8*20 +: 20] <= {10'd150, 10'd375}; // bottom strip left
                coin_bus[ 9*20 +: 20] <= {10'd230, 10'd245}; // detour mid-left
                coin_bus[10*20 +: 20] <= {10'd350, 10'd245}; // detour centre
                coin_bus[11*20 +: 20] <= {10'd460, 10'd245}; // detour mid-right
            end

            // ═══════════════════════════════════════════════════════════════
            // LAYOUT 1 — S-curve / slalom
            // ═══════════════════════════════════════════════════════════════
            2'd1: begin
                num_segs  <= 4'd9;
                num_cones <= 4'd8;
                num_bldgs <= 4'd6;
                num_coins <= 4'd12;

                seg_bus[0*40 +: 40] <= {10'd20,  10'd130, 10'd70,  10'd400};
                seg_bus[1*40 +: 40] <= {10'd20,  10'd130, 10'd350, 10'd185};
                seg_bus[2*40 +: 40] <= {10'd300, 10'd185, 10'd350, 10'd310};
                seg_bus[3*40 +: 40] <= {10'd300, 10'd260, 10'd590, 10'd310};
                seg_bus[4*40 +: 40] <= {10'd540, 10'd310, 10'd590, 10'd420};
                seg_bus[5*40 +: 40] <= {10'd20,  10'd370, 10'd590, 10'd420};
                seg_bus[6*40 +: 40] <= {10'd20,  10'd370, 10'd70,  10'd400};
                seg_bus[7*40 +: 40] <= {10'd300, 10'd130, 10'd590, 10'd185};
                seg_bus[8*40 +: 40] <= {10'd540, 10'd185, 10'd590, 10'd310};

                cone_bus[0*20 +: 20] <= {10'd70,  10'd157};
                cone_bus[1*20 +: 20] <= {10'd325, 10'd157};
                cone_bus[2*20 +: 20] <= {10'd565, 10'd157};
                cone_bus[3*20 +: 20] <= {10'd325, 10'd285};
                cone_bus[4*20 +: 20] <= {10'd565, 10'd335};
                cone_bus[5*20 +: 20] <= {10'd325, 10'd395};
                cone_bus[6*20 +: 20] <= {10'd70,  10'd395};
                cone_bus[7*20 +: 20] <= {10'd450, 10'd235};

                bldg_bus[0*36 +: 36] <= {10'd100, 10'd150, 8'd80, 8'd90};
                bldg_bus[1*36 +: 36] <= {10'd300, 10'd150, 8'd80, 8'd90};
                bldg_bus[2*36 +: 36] <= {10'd100, 10'd200, 8'd60, 8'd50};
                bldg_bus[3*36 +: 36] <= {10'd400, 10'd200, 8'd60, 8'd50};
                bldg_bus[4*36 +: 36] <= {10'd100, 10'd310, 8'd60, 8'd50};
                bldg_bus[5*36 +: 36] <= {10'd180, 10'd310, 8'd60, 8'd50};

                coin_bus[ 0*20 +: 20] <= {10'd45,  10'd200}; // left corridor
                coin_bus[ 1*20 +: 20] <= {10'd45,  10'd330}; // left corridor lower
                coin_bus[ 2*20 +: 20] <= {10'd150, 10'd157}; // top-left shelf
                coin_bus[ 3*20 +: 20] <= {10'd220, 10'd157}; // top-left shelf
                coin_bus[ 4*20 +: 20] <= {10'd420, 10'd157}; // top-right shelf
                coin_bus[ 5*20 +: 20] <= {10'd500, 10'd157}; // top-right shelf
                coin_bus[ 6*20 +: 20] <= {10'd325, 10'd230}; // mid-left vert
                coin_bus[ 7*20 +: 20] <= {10'd420, 10'd285}; // mid horizontal
                coin_bus[ 8*20 +: 20] <= {10'd500, 10'd285}; // mid horizontal
                coin_bus[ 9*20 +: 20] <= {10'd565, 10'd360}; // right vert lower
                coin_bus[10*20 +: 20] <= {10'd350, 10'd395}; // bottom strip
                coin_bus[11*20 +: 20] <= {10'd180, 10'd395}; // bottom strip
            end

            // ═══════════════════════════════════════════════════════════════
            // LAYOUT 2 — figure-eight / cross-pattern
            // ═══════════════════════════════════════════════════════════════
            2'd2: begin
                num_segs  <= 4'd10;
                num_cones <= 4'd8;
                num_bldgs <= 4'd6;
                num_coins <= 4'd12;

                seg_bus[0*40 +: 40] <= {10'd20,  10'd130, 10'd70,  10'd400};
                seg_bus[1*40 +: 40] <= {10'd20,  10'd130, 10'd360, 10'd180};
                seg_bus[2*40 +: 40] <= {10'd310, 10'd130, 10'd590, 10'd180};
                seg_bus[3*40 +: 40] <= {10'd540, 10'd130, 10'd590, 10'd280};
                seg_bus[4*40 +: 40] <= {10'd20,  10'd240, 10'd590, 10'd290};
                seg_bus[5*40 +: 40] <= {10'd20,  10'd240, 10'd70,  10'd400};
                seg_bus[6*40 +: 40] <= {10'd540, 10'd240, 10'd590, 10'd400};
                seg_bus[7*40 +: 40] <= {10'd20,  10'd350, 10'd310, 10'd400};
                seg_bus[8*40 +: 40] <= {10'd310, 10'd350, 10'd590, 10'd400};
                seg_bus[9*40 +: 40] <= {10'd310, 10'd130, 10'd360, 10'd400};

                cone_bus[0*20 +: 20] <= {10'd70,  10'd155};
                cone_bus[1*20 +: 20] <= {10'd335, 10'd155};
                cone_bus[2*20 +: 20] <= {10'd565, 10'd155};
                cone_bus[3*20 +: 20] <= {10'd565, 10'd265};
                cone_bus[4*20 +: 20] <= {10'd335, 10'd265};
                cone_bus[5*20 +: 20] <= {10'd70,  10'd265};
                cone_bus[6*20 +: 20] <= {10'd70,  10'd375};
                cone_bus[7*20 +: 20] <= {10'd565, 10'd375};

                bldg_bus[0*36 +: 36] <= {10'd100, 10'd150, 8'd80, 8'd90};
                bldg_bus[1*36 +: 36] <= {10'd400, 10'd150, 8'd80, 8'd90};
                bldg_bus[2*36 +: 36] <= {10'd100, 10'd195, 8'd60, 8'd35};
                bldg_bus[3*36 +: 36] <= {10'd400, 10'd195, 8'd60, 8'd35};
                bldg_bus[4*36 +: 36] <= {10'd100, 10'd310, 8'd80, 8'd30};
                bldg_bus[5*36 +: 36] <= {10'd400, 10'd310, 8'd80, 8'd30};

                coin_bus[ 0*20 +: 20] <= {10'd45,  10'd190}; // left corridor upper
                coin_bus[ 1*20 +: 20] <= {10'd45,  10'd320}; // left corridor lower
                coin_bus[ 2*20 +: 20] <= {10'd160, 10'd155}; // top-left horiz
                coin_bus[ 3*20 +: 20] <= {10'd240, 10'd155}; // top-left horiz
                coin_bus[ 4*20 +: 20] <= {10'd430, 10'd155}; // top-right horiz
                coin_bus[ 5*20 +: 20] <= {10'd510, 10'd155}; // top-right horiz
                coin_bus[ 6*20 +: 20] <= {10'd565, 10'd205}; // right vert top
                coin_bus[ 7*20 +: 20] <= {10'd150, 10'd265}; // center band
                coin_bus[ 8*20 +: 20] <= {10'd450, 10'd265}; // center band
                coin_bus[ 9*20 +: 20] <= {10'd335, 10'd220}; // center cross vert
                coin_bus[10*20 +: 20] <= {10'd160, 10'd375}; // bottom-left horiz
                coin_bus[11*20 +: 20] <= {10'd460, 10'd375}; // bottom-right horiz
            end

            // ═══════════════════════════════════════════════════════════════
            // LAYOUT 3 — spiral / nested rectangles
            // ═══════════════════════════════════════════════════════════════
            2'd3: begin
                num_segs  <= 4'd12;
                num_cones <= 4'd8;
                num_bldgs <= 4'd6;
                num_coins <= 4'd12;

                seg_bus[ 0*40 +: 40] <= {10'd20,  10'd130, 10'd70,  10'd400};
                seg_bus[ 1*40 +: 40] <= {10'd20,  10'd130, 10'd590, 10'd180};
                seg_bus[ 2*40 +: 40] <= {10'd540, 10'd130, 10'd590, 10'd400};
                seg_bus[ 3*40 +: 40] <= {10'd20,  10'd350, 10'd590, 10'd400};
                seg_bus[ 4*40 +: 40] <= {10'd100, 10'd210, 10'd490, 10'd260};
                seg_bus[ 5*40 +: 40] <= {10'd440, 10'd210, 10'd490, 10'd330};
                seg_bus[ 6*40 +: 40] <= {10'd100, 10'd280, 10'd490, 10'd330};
                seg_bus[ 7*40 +: 40] <= {10'd100, 10'd210, 10'd150, 10'd330};
                seg_bus[ 8*40 +: 40] <= {10'd70,  10'd180, 10'd150, 10'd260};
                seg_bus[ 9*40 +: 40] <= {10'd440, 10'd180, 10'd540, 10'd260};
                seg_bus[10*40 +: 40] <= {10'd70,  10'd280, 10'd150, 10'd355};
                seg_bus[11*40 +: 40] <= {10'd440, 10'd280, 10'd540, 10'd355};

                cone_bus[0*20 +: 20] <= {10'd70,  10'd155};
                cone_bus[1*20 +: 20] <= {10'd565, 10'd155};
                cone_bus[2*20 +: 20] <= {10'd565, 10'd375};
                cone_bus[3*20 +: 20] <= {10'd70,  10'd375};
                cone_bus[4*20 +: 20] <= {10'd125, 10'd235};
                cone_bus[5*20 +: 20] <= {10'd465, 10'd235};
                cone_bus[6*20 +: 20] <= {10'd465, 10'd305};
                cone_bus[7*20 +: 20] <= {10'd125, 10'd305};

                bldg_bus[0*36 +: 36] <= {10'd170, 10'd150, 8'd60, 8'd90};
                bldg_bus[1*36 +: 36] <= {10'd320, 10'd150, 8'd60, 8'd90};
                bldg_bus[2*36 +: 36] <= {10'd470, 10'd150, 8'd60, 8'd90};
                bldg_bus[3*36 +: 36] <= {10'd200, 10'd235, 8'd80, 8'd40};
                bldg_bus[4*36 +: 36] <= {10'd300, 10'd235, 8'd80, 8'd40};
                bldg_bus[5*36 +: 36] <= {10'd200, 10'd420, 8'd80, 8'd50};

                coin_bus[ 0*20 +: 20] <= {10'd45,  10'd200}; // left corridor
                coin_bus[ 1*20 +: 20] <= {10'd45,  10'd320}; // left corridor lower
                coin_bus[ 2*20 +: 20] <= {10'd200, 10'd155}; // outer top
                coin_bus[ 3*20 +: 20] <= {10'd380, 10'd155}; // outer top
                coin_bus[ 4*20 +: 20] <= {10'd565, 10'd250}; // outer right
                coin_bus[ 5*20 +: 20] <= {10'd420, 10'd375}; // outer bottom
                coin_bus[ 6*20 +: 20] <= {10'd230, 10'd375}; // outer bottom
                coin_bus[ 7*20 +: 20] <= {10'd270, 10'd235}; // inner top mid
                coin_bus[ 8*20 +: 20] <= {10'd380, 10'd235}; // inner top right
                coin_bus[ 9*20 +: 20] <= {10'd125, 10'd305}; // inner bottom left
                coin_bus[10*20 +: 20] <= {10'd270, 10'd305}; // inner bottom mid
                coin_bus[11*20 +: 20] <= {10'd380, 10'd305}; // inner bottom right
            end
        endcase

        // --- Optionally mirror entire layout horizontally for variety
        if (lfsr[2]) begin
            // mirror seg_bus: x' = 639 - x (swap left/right correctly)
            new_seg_bus = seg_bus;
            for (i = 0; i < `MAX_SEGS; i = i + 1) begin
                if (i < num_segs) begin
                    sx1 = seg_bus[i*40+39 -: 10]; sy1 = seg_bus[i*40+29 -: 10];
                    sx2 = seg_bus[i*40+19 -: 10]; sy2 = seg_bus[i*40+ 9 -: 10];
                    new_seg_bus[i*40 +: 40] = {10'd639 - sx2, sy1, 10'd639 - sx1, sy2};
                end
            end
            seg_bus <= new_seg_bus;

            // mirror cones
            for (i = 0; i < `MAX_CONES; i = i + 1) begin
                if (i < num_cones) begin
                    cx = cone_bus[i*20+19 -: 10]; cy = cone_bus[i*20+9 -: 10];
                    cone_bus[i*20 +: 20] <= {10'd639 - cx, cy};
                end
            end

            // mirror buildings (top-left coordinate must be recalculated)
            new_bldg_bus = bldg_bus;
            for (i = 0; i < `MAX_BLDGS; i = i + 1) begin
                if (i < num_bldgs) begin
                    bx = bldg_bus[i*36+35 -: 10]; by = bldg_bus[i*36+25 -: 10];
                    bw = bldg_bus[i*36+15 -:  8]; bh = bldg_bus[i*36+ 7 -:  8];
                    nbx = 10'd639 - (bx + {2'b0,bw} - 10'd1);
                    new_bldg_bus[i*36 +: 36] = {nbx, by, bw, bh};
                end
            end
            bldg_bus <= new_bldg_bus;

            // mirror coins
            for (i = 0; i < `MAX_COINS; i = i + 1) begin
                if (i < num_coins) begin
                    cx = coin_bus[i*20+19 -: 10]; cy = coin_bus[i*20+9 -: 10];
                    coin_bus[i*20 +: 20] <= {10'd639 - cx, cy};
                end
            end
        end

        // --- Fill remaining building slots with grass patches (marked via bw[7])
        for (gi = 0; gi < `MAX_BLDGS; gi = gi + 1) begin
            if (gi >= num_bldgs) begin
                // Simple pseudo-random placement using LFSR slices mixed with index
                gbx = 10'd80 + ((lfsr[9:2] + gi*13) % 10'd460);
                gby = 10'd120 + ((lfsr[7:0]  + gi*7)  % 10'd240);
                gbw = 8'd16 + ((lfsr[11:8] + gi) & 8'h0F);
                gbh = 8'd12 + ((lfsr[15:12] + gi) & 8'h0F);
                gbw = gbw | 8'h80; // set MSB to mark grass
                bldg_bus[gi*36 +: 36] <= {gbx, gby, gbw, gbh};
            end
        end
        num_bldgs <= `MAX_BLDGS;
    end
end

endmodule