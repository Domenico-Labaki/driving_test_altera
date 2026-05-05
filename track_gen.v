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
// Fixed constants (start bay, parking box, car spawn) are in track_data.vh.
//
// Screen: 640×480.
// Start bay (also parking exit): x=20..70, y=310..400
// Parking box (finish):          x=20..80, y=130..175
// Car spawns at (45, 360) heading 270° (north).

`include "track_data.vh"

module track_gen (
    input  wire        clk50,
    input  wire        rst_n,
    input  wire        reload,
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
    output reg  [3:0]                  num_coins,
    // Placement validity: asserted when all cones/coins are on-track
    // and no coin shares a position with a cone.
    output wire                         placement_valid
);

// temporaries for procedural mirroring / grass placement
integer i, gi;
reg [(`MAX_SEGS*40)-1:0] new_seg_bus;
reg [(`MAX_BLDGS*36)-1:0] new_bldg_bus;
reg [9:0] sx1,sy1,sx2,sy2;
reg [9:0] cx,cy;
reg [9:0] bx,by,nbx,gbx,gby;
reg [7:0] bw,bh,gbw,gbh;

// ── Placement validation ──────────────────────────────────────────────────
integer vi, vj, vk;
reg [9:0] v_px, v_py, v_x1, v_y1, v_x2, v_y2, v_cnx, v_cny;
reg       v_hit;
reg [9:0] c_px, c_py, c_x1, c_y1, c_x2, c_y2, c_cnx, c_cny;
reg       c_hit;
reg [`MAX_CONES-1:0] cone_ok;
reg [`MAX_COINS-1:0] coin_ok;
reg no_overlap;
assign placement_valid = (&cone_ok) & (&coin_ok) & no_overlap;
reg do_validate;

// ── Free-running LFSR (16-bit Fibonacci, taps 16,15,13,4) ────────────────
reg [15:0] lfsr;
always @(posedge clk50)
    lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[14] ^ lfsr[12] ^ lfsr[3]};

reg [1:0] layout_idx = 2'd0;

// ── Reset rising-edge detector ────────────────────────────────────────────
reg rst_prev;
always @(posedge clk50) begin
    rst_prev    <= rst_n;
    do_validate <= load_track;
end
wire load_track = (rst_n & ~rst_prev) | reload;

// ── Layout load ───────────────────────────────────────────────────────────
always @(posedge clk50) begin
    if (load_track) begin
        seg_bus  <= 0;
        cone_bus <= 0;
        bldg_bus <= 0;
        coin_bus <= 0;

        case (layout_idx)

            // ═══════════════════════════════════════════════════════════════
            // LAYOUT 0 — Clockwise outer loop with inner detour
            //
            // Route: start bay (left, mid) → drive north up left corridor →
            //   turn right across the top → turn right down the right side →
            //   turn right across the bottom → back to start bay.
            //   Inner detour: a horizontal bypass through the centre, entered
            //   from the left corridor and exited at the right corridor,
            //   giving drivers a shortcut option.
            //
            // Road map (640×480, Y↓):
            //   Left corridor:  x=20..70,  y=130..400  (covers parking+start)
            //   Top strip:      x=20..620, y=130..180
            //   Right corridor: x=570..620,y=130..400
            //   Bottom strip:   x=20..620, y=350..400
            //   Detour horiz:   x=70..570, y=240..290
            //   Detour left jn: x=20..120, y=240..290  (connects left to detour)
            //   Detour right jn:x=520..620,y=240..290  (connects detour to right)
            // ═══════════════════════════════════════════════════════════════
            2'd0: begin
                num_segs  <= 4'd7;
                num_cones <= 4'd8;
                num_bldgs <= 4'd4;
                num_coins <= 4'd12;

                // Road segments
                // seg 0: left corridor (covers start bay y=310..400 and parking y=130..175)
                seg_bus[0*40 +: 40] <= {10'd20,  10'd130, 10'd70,  10'd400};
                // seg 1: top strip
                seg_bus[1*40 +: 40] <= {10'd20,  10'd130, 10'd620, 10'd180};
                // seg 2: right corridor
                seg_bus[2*40 +: 40] <= {10'd570, 10'd130, 10'd620, 10'd400};
                // seg 3: bottom strip
                seg_bus[3*40 +: 40] <= {10'd20,  10'd350, 10'd620, 10'd400};
                // seg 4: inner detour horizontal
                seg_bus[4*40 +: 40] <= {10'd70,  10'd240, 10'd570, 10'd290};
                // seg 5: detour left junction (widens left corridor at detour level)
                seg_bus[5*40 +: 40] <= {10'd20,  10'd240, 10'd120, 10'd290};
                // seg 6: detour right junction
                seg_bus[6*40 +: 40] <= {10'd520, 10'd240, 10'd620, 10'd290};

                // Cones — placed at corridor entrances and detour decision points
                // NW corner of outer loop
                cone_bus[0*20 +: 20] <= {10'd45,  10'd200};
                // NE corner
                cone_bus[1*20 +: 20] <= {10'd595, 10'd200};
                // SE corner
                cone_bus[2*20 +: 20] <= {10'd595, 10'd330};
                // SW corner
                cone_bus[3*20 +: 20] <= {10'd45,  10'd330};
                // Detour entry left (nudges driver to choose inside or outside)
                cone_bus[4*20 +: 20] <= {10'd100, 10'd265};
                // Detour entry right
                cone_bus[5*20 +: 20] <= {10'd540, 10'd265};
                // Top strip mid (forces wide line through top)
                cone_bus[6*20 +: 20] <= {10'd320, 10'd155};
                // Bottom strip mid
                cone_bus[7*20 +: 20] <= {10'd320, 10'd375};

                // Buildings — block off-road islands inside the outer loop
                // Large centre-left island
                bldg_bus[0*36 +: 36] <= {10'd100, 10'd185, 8'd200, 8'd50};
                // Large centre-right island
                bldg_bus[1*36 +: 36] <= {10'd340, 10'd185, 8'd200, 8'd50};
                // Centre lower-left island
                bldg_bus[2*36 +: 36] <= {10'd100, 10'd295, 8'd180, 8'd50};
                // Centre lower-right island
                bldg_bus[3*36 +: 36] <= {10'd340, 10'd295, 8'd180, 8'd50};

                // Coins — well inside road, clear of all cones and buildings
                // Left corridor: 3 coins going north
                coin_bus[ 0*20 +: 20] <= {10'd45,  10'd320};
                coin_bus[ 1*20 +: 20] <= {10'd45,  10'd215};
                coin_bus[ 2*20 +: 20] <= {10'd45,  10'd250};
                // Top strip: 3 coins spread across
                coin_bus[ 3*20 +: 20] <= {10'd200, 10'd155};
                coin_bus[ 4*20 +: 20] <= {10'd420, 10'd155};
                coin_bus[ 5*20 +: 20] <= {10'd595, 10'd155};
                // Right corridor: 2 coins
                coin_bus[ 6*20 +: 20] <= {10'd595, 10'd265};
                coin_bus[ 7*20 +: 20] <= {10'd595, 10'd375};
                // Bottom strip: 2 coins
                coin_bus[ 8*20 +: 20] <= {10'd420, 10'd375};
                coin_bus[ 9*20 +: 20] <= {10'd200, 10'd375};
                // Detour: 2 coins
                coin_bus[10*20 +: 20] <= {10'd200, 10'd265};
                coin_bus[11*20 +: 20] <= {10'd420, 10'd265};
            end

            // ═══════════════════════════════════════════════════════════════
            // LAYOUT 1 — S-curve / slalom
            //
            // Route: start bay → north up left side → bend right to centre-top
            //   → bend down through centre → bend right to right side →
            //   down right corridor → bend left across bottom → back to start.
            //
            // The road traces a shallow S through the screen.
            // Cones are placed at the apex of each bend as slalom gates —
            // the driver must thread through them without hitting.
            //
            // Road map:
            //   Left vertical:     x=20..70,   y=200..400
            //   Top-left horiz:    x=20..330,  y=130..200
            //   Centre vertical:   x=280..330, y=130..340
            //   Centre-lower horiz:x=280..640, y=290..340  (but capped at 620)
            //   Right vertical:    x=570..620, y=130..340
            //   Top-right horiz:   x=330..620, y=130..180
            //   Bottom horiz:      x=20..620,  y=350..400
            // ═══════════════════════════════════════════════════════════════
            2'd1: begin
                num_segs  <= 4'd7;
                num_cones <= 4'd8;
                num_bldgs <= 4'd4;
                num_coins <= 4'd12;

                // Road segments
                // seg 0: left vertical (start bay → top-left bend)
                seg_bus[0*40 +: 40] <= {10'd20,  10'd130, 10'd70,  10'd400};
                // seg 1: top-left horizontal shelf
                seg_bus[1*40 +: 40] <= {10'd20,  10'd130, 10'd330, 10'd185};
                // seg 2: centre vertical — the spine of the S
                seg_bus[2*40 +: 40] <= {10'd280, 10'd130, 10'd330, 10'd340};
                // seg 3: centre-lower horizontal — swings right
                seg_bus[3*40 +: 40] <= {10'd280, 10'd290, 10'd620, 10'd340};
                // seg 4: right vertical
                seg_bus[4*40 +: 40] <= {10'd570, 10'd130, 10'd620, 10'd340};
                // seg 5: top-right horizontal shelf
                seg_bus[5*40 +: 40] <= {10'd310, 10'd130, 10'd620, 10'd185};
                // seg 6: bottom strip (connects right back to start bay)
                seg_bus[6*40 +: 40] <= {10'd20,  10'd350, 10'd620, 10'd400};

                // Cones — slalom gates at the three bends of the S
                // Gate 1: top-left bend (driver must go right here)
                cone_bus[0*20 +: 20] <= {10'd45,  10'd200};
                cone_bus[1*20 +: 20] <= {10'd200, 10'd160};
                // Gate 2: centre spine (driver must choose left or right side of spine)
                cone_bus[2*20 +: 20] <= {10'd305, 10'd200};
                cone_bus[3*20 +: 20] <= {10'd305, 10'd250};
                // Gate 3: centre-lower bend (driver must go right)
                cone_bus[4*20 +: 20] <= {10'd400, 10'd315};
                cone_bus[5*20 +: 20] <= {10'd520, 10'd315};
                // Top-right corner guards
                cone_bus[6*20 +: 20] <= {10'd595, 10'd160};
                // Bottom-left corner guard
                cone_bus[7*20 +: 20] <= {10'd45,  10'd375};

                // Buildings — frame the off-road areas around the S
                // Block between left corridor and centre spine (upper)
                bldg_bus[0*36 +: 36] <= {10'd80,  10'd195, 8'd180, 8'd90};
                // Block right of centre spine (upper)
                bldg_bus[1*36 +: 36] <= {10'd345, 10'd195, 8'd200, 8'd90};
                // Block left of centre-lower horizontal
                bldg_bus[2*36 +: 36] <= {10'd80,  10'd200, 8'd180, 8'd85};
                // Block above bottom strip, right side
                bldg_bus[3*36 +: 36] <= {10'd345, 10'd200, 8'd200, 8'd85};

                // Coins — along each segment of the S
                // Left corridor going up
                coin_bus[ 0*20 +: 20] <= {10'd45,  10'd360};
                coin_bus[ 1*20 +: 20] <= {10'd45,  10'd280};
                // Top-left shelf going right
                coin_bus[ 2*20 +: 20] <= {10'd100, 10'd157};
                coin_bus[ 3*20 +: 20] <= {10'd220, 10'd157};
                // Top-right shelf going right
                coin_bus[ 4*20 +: 20] <= {10'd420, 10'd157};
                coin_bus[ 5*20 +: 20] <= {10'd540, 10'd157};
                // Centre spine going down
                coin_bus[ 6*20 +: 20] <= {10'd305, 10'd220};
                coin_bus[ 7*20 +: 20] <= {10'd305, 10'd270};
                // Centre-lower shelf going right
                coin_bus[ 8*20 +: 20] <= {10'd380, 10'd315};
                coin_bus[ 9*20 +: 20] <= {10'd500, 10'd315};
                // Right corridor going down
                coin_bus[10*20 +: 20] <= {10'd595, 10'd157};
                // Bottom strip going left
                coin_bus[11*20 +: 20] <= {10'd300, 10'd375};
            end

            // ═══════════════════════════════════════════════════════════════
            // LAYOUT 2 — Figure-eight / cross-pattern
            //
            // Two loops share a central vertical corridor, forming a figure-8.
            // Route: start bay → north up left side → across top-left →
            //   down centre vertical → across bottom-right → up right side →
            //   across top-right → down centre → across bottom-left → back.
            //
            // Road map:
            //   Left corridor:   x=20..70,   y=130..400
            //   Top-left horiz:  x=20..350,  y=130..180
            //   Centre vertical: x=300..350, y=130..400
            //   Top-right horiz: x=300..620, y=130..180
            //   Right corridor:  x=570..620, y=130..400
            //   Bottom-left:     x=20..350,  y=350..400
            //   Bottom-right:    x=300..620, y=350..400
            // ═══════════════════════════════════════════════════════════════
            2'd2: begin
                num_segs  <= 4'd7;
                num_cones <= 4'd8;
                num_bldgs <= 4'd4;
                num_coins <= 4'd12;

                // Road segments
                // seg 0: left corridor
                seg_bus[0*40 +: 40] <= {10'd20,  10'd130, 10'd70,  10'd400};
                // seg 1: top-left horizontal
                seg_bus[1*40 +: 40] <= {10'd20,  10'd130, 10'd350, 10'd180};
                // seg 2: centre vertical (the crossing spine)
                seg_bus[2*40 +: 40] <= {10'd300, 10'd130, 10'd350, 10'd400};
                // seg 3: top-right horizontal
                seg_bus[3*40 +: 40] <= {10'd300, 10'd130, 10'd620, 10'd180};
                // seg 4: right corridor
                seg_bus[4*40 +: 40] <= {10'd570, 10'd130, 10'd620, 10'd400};
                // seg 5: bottom-left horizontal
                seg_bus[5*40 +: 40] <= {10'd20,  10'd350, 10'd350, 10'd400};
                // seg 6: bottom-right horizontal
                seg_bus[6*40 +: 40] <= {10'd300, 10'd350, 10'd620, 10'd400};

                // Cones — at the four corners of each loop and at the crossing
                // Top-left corner
                cone_bus[0*20 +: 20] <= {10'd45,  10'd200};
                // Top-right corner
                cone_bus[1*20 +: 20] <= {10'd595, 10'd155};
                // Bottom-left corner
                cone_bus[2*20 +: 20] <= {10'd45,  10'd375};
                // Bottom-right corner
                cone_bus[3*20 +: 20] <= {10'd595, 10'd375};
                // Crossing entry top (forces caution at the figure-8 cross)
                cone_bus[4*20 +: 20] <= {10'd325, 10'd155};
                // Crossing entry bottom
                cone_bus[5*20 +: 20] <= {10'd325, 10'd375};
                // Left loop mid guard (left corridor)
                cone_bus[6*20 +: 20] <= {10'd45,  10'd265};
                // Right loop mid guard (right corridor)
                cone_bus[7*20 +: 20] <= {10'd595, 10'd265};

                // Buildings — fill the interior of each loop
                // Left loop interior (upper)
                bldg_bus[0*36 +: 36] <= {10'd80,  10'd190, 8'd200, 8'd150};
                // Right loop interior (upper)
                bldg_bus[1*36 +: 36] <= {10'd365, 10'd190, 8'd185, 8'd150};
                // Left loop interior (lower) — same block, already covered above
                // Right loop interior (lower)
                bldg_bus[2*36 +: 36] <= {10'd80,  10'd195, 8'd195, 8'd145};
                bldg_bus[3*36 +: 36] <= {10'd370, 10'd195, 8'd180, 8'd145};

                // Coins — distributed around both loops
                // Left corridor
                coin_bus[ 0*20 +: 20] <= {10'd45,  10'd300};
                coin_bus[ 1*20 +: 20] <= {10'd45,  10'd210};
                // Top-left
                coin_bus[ 2*20 +: 20] <= {10'd150, 10'd155};
                coin_bus[ 3*20 +: 20] <= {10'd250, 10'd155};
                // Top-right
                coin_bus[ 4*20 +: 20] <= {10'd420, 10'd155};
                coin_bus[ 5*20 +: 20] <= {10'd550, 10'd155};
                // Right corridor
                coin_bus[ 6*20 +: 20] <= {10'd595, 10'd210};
                coin_bus[ 7*20 +: 20] <= {10'd595, 10'd310};
                // Bottom-right
                coin_bus[ 8*20 +: 20] <= {10'd460, 10'd375};
                // Centre vertical (the cross — clear of cones at top/bottom)
                coin_bus[ 9*20 +: 20] <= {10'd325, 10'd265};
                // Bottom-left
                coin_bus[10*20 +: 20] <= {10'd200, 10'd375};
                // Left corridor lower
                coin_bus[11*20 +: 20] <= {10'd45,  10'd365};
            end

            // ═══════════════════════════════════════════════════════════════
            // LAYOUT 3 — Spiral / nested rectangles
            //
            // Outer rectangle loop + inner rectangle loop connected by two
            // short passages (left and right), creating a spiral feel.
            // Driver does the outer loop, dips into the inner loop via the
            // left passage, traverses the inner loop, exits via the right
            // passage, and completes the outer loop back to start.
            //
            // Road map:
            //   Left corridor (outer): x=20..70,  y=130..400
            //   Top strip (outer):     x=20..620, y=130..180
            //   Right corridor (outer):x=570..620,y=130..400
            //   Bottom strip (outer):  x=20..620, y=350..400
            //   Left passage (in→out): x=20..170, y=215..265
            //   Right passage (in→out):x=470..620,y=215..265
            //   Inner top:             x=120..520,y=215..265
            //   Inner bottom:          x=120..520,y=275..325
            //   Inner left vert:       x=120..170,y=215..325
            //   Inner right vert:      x=470..520,y=215..325
            // ═══════════════════════════════════════════════════════════════
            2'd3: begin
                num_segs  <= 4'd10;
                num_cones <= 4'd8;
                num_bldgs <= 4'd4;
                num_coins <= 4'd12;

                // Road segments
                // Outer loop
                seg_bus[0*40 +: 40] <= {10'd20,  10'd130, 10'd70,  10'd400};  // left corridor
                seg_bus[1*40 +: 40] <= {10'd20,  10'd130, 10'd620, 10'd180};  // top strip
                seg_bus[2*40 +: 40] <= {10'd570, 10'd130, 10'd620, 10'd400};  // right corridor
                seg_bus[3*40 +: 40] <= {10'd20,  10'd350, 10'd620, 10'd400};  // bottom strip
                // Passages connecting outer to inner
                seg_bus[4*40 +: 40] <= {10'd20,  10'd215, 10'd170, 10'd265};  // left passage
                seg_bus[5*40 +: 40] <= {10'd470, 10'd215, 10'd620, 10'd265};  // right passage
                // Inner rectangle
                seg_bus[6*40 +: 40] <= {10'd120, 10'd215, 10'd520, 10'd265};  // inner top horiz
                seg_bus[7*40 +: 40] <= {10'd120, 10'd275, 10'd520, 10'd325};  // inner bottom horiz
                seg_bus[8*40 +: 40] <= {10'd120, 10'd215, 10'd170, 10'd325};  // inner left vert
                seg_bus[9*40 +: 40] <= {10'd470, 10'd215, 10'd520, 10'd325};  // inner right vert

                // Cones — outer corners and inner rectangle entry/exit guards
                // Outer top corners
                cone_bus[0*20 +: 20] <= {10'd45,  10'd200};
                cone_bus[1*20 +: 20] <= {10'd595, 10'd155};
                // Outer bottom corners
                cone_bus[2*20 +: 20] <= {10'd45,  10'd375};
                cone_bus[3*20 +: 20] <= {10'd595, 10'd375};
                // Inner rectangle entry guards (at the mouth of each passage)
                cone_bus[4*20 +: 20] <= {10'd145, 10'd240};
                cone_bus[5*20 +: 20] <= {10'd495, 10'd240};
                // Inner rectangle mid-section guides
                cone_bus[6*20 +: 20] <= {10'd320, 10'd240};
                cone_bus[7*20 +: 20] <= {10'd320, 10'd300};

                // Buildings — frame outer corridor walls and inner island
                // Inner island (between inner top and bottom horiz)
                bldg_bus[0*36 +: 36] <= {10'd180, 10'd215, 8'd270, 8'd110};
                // Left outer wall fill (between left corridor and left passage)
                bldg_bus[1*36 +: 36] <= {10'd80,  10'd190, 8'd30,  8'd20};
                // Right outer wall fill
                bldg_bus[2*36 +: 36] <= {10'd530, 10'd190, 8'd30,  8'd20};
                // Top outer centre decoration
                bldg_bus[3*36 +: 36] <= {10'd200, 10'd190, 8'd240, 8'd20};

                // Coins — outer loop and inner rectangle
                // Left corridor going north
                coin_bus[ 0*20 +: 20] <= {10'd45,  10'd360};
                coin_bus[ 1*20 +: 20] <= {10'd45,  10'd280};
                // Top strip
                coin_bus[ 2*20 +: 20] <= {10'd200, 10'd155};
                coin_bus[ 3*20 +: 20] <= {10'd420, 10'd155};
                // Right corridor
                coin_bus[ 4*20 +: 20] <= {10'd595, 10'd280};
                coin_bus[ 5*20 +: 20] <= {10'd595, 10'd200};
                // Bottom strip
                coin_bus[ 6*20 +: 20] <= {10'd420, 10'd375};
                coin_bus[ 7*20 +: 20] <= {10'd200, 10'd375};
                // Inner top horizontal
                coin_bus[ 8*20 +: 20] <= {10'd250, 10'd240};
                coin_bus[ 9*20 +: 20] <= {10'd390, 10'd240};
                // Inner bottom horizontal
                coin_bus[10*20 +: 20] <= {10'd250, 10'd300};
                coin_bus[11*20 +: 20] <= {10'd390, 10'd300};
            end
        endcase

        // Advance to the next layout for the next reset cycle.
        layout_idx <= layout_idx + 2'd1;

        // Mirroring disabled — layouts used as defined (no optional horizontal flip).

        // --- Fill remaining building slots with pseudo-random grass patches
        for (gi = 0; gi < `MAX_BLDGS; gi = gi + 1) begin
            if (gi >= num_bldgs) begin
                gbx = 10'd80 + ((lfsr[9:2] + gi*13) % 10'd460);
                gby = 10'd120 + ((lfsr[7:0]  + gi*7)  % 10'd240);
                gbw = 8'd16 + ((lfsr[11:8] + gi) & 8'h0F);
                gbh = 8'd12 + ((lfsr[15:12] + gi) & 8'h0F);
                // Render as buildings instead of grass
                bldg_bus[gi*36 +: 36] <= {gbx, gby, gbw, gbh};
            end
        end
        num_bldgs <= `MAX_BLDGS;
    end

    // ── Correction phase ─────────────────────────────────────────────────────
    if (do_validate) begin

        // --- Correct each coin ---
        for (vi = 0; vi < `MAX_COINS; vi = vi + 1) begin
            if (vi < num_coins) begin
                v_px = coin_bus[vi*20+19 -: 10];
                v_py = coin_bus[vi*20+ 9 -: 10];

                for (vk = 0; vk < `MAX_CONES; vk = vk + 1) begin
                    if (vk < num_cones) begin
                        v_cnx = cone_bus[vk*20+19 -: 10];
                        v_cny = cone_bus[vk*20+ 9 -: 10];
                        if (v_px == v_cnx && v_py == v_cny)
                            v_px = v_px + 10'd15;
                    end
                end

                v_hit = 1'b0;
                for (vj = 0; vj < `MAX_SEGS; vj = vj + 1) begin
                    if (vj < num_segs) begin
                        v_x1 = seg_bus[vj*40+39 -: 10]; v_y1 = seg_bus[vj*40+29 -: 10];
                        v_x2 = seg_bus[vj*40+19 -: 10]; v_y2 = seg_bus[vj*40+ 9 -: 10];
                        if (v_px >= v_x1 && v_px <= v_x2 && v_py >= v_y1 && v_py <= v_y2)
                            v_hit = 1'b1;
                    end
                end
                if (!v_hit) begin
                    v_x1 = seg_bus[39 -: 10]; v_x2 = seg_bus[19 -: 10];
                    v_y1 = seg_bus[29 -: 10]; v_y2 = seg_bus[ 9 -: 10];
                    v_px = (v_x1 + v_x2) >> 1;
                    v_py = (v_y1 + v_y2) >> 1;
                end

                coin_bus[vi*20 +: 20] <= {v_px, v_py};
            end
        end

        // --- Correct each cone ---
        for (vi = 0; vi < `MAX_CONES; vi = vi + 1) begin
            if (vi < num_cones) begin
                v_cnx = cone_bus[vi*20+19 -: 10];
                v_cny = cone_bus[vi*20+ 9 -: 10];
                v_hit = 1'b0;
                for (vj = 0; vj < `MAX_SEGS; vj = vj + 1) begin
                    if (vj < num_segs) begin
                        v_x1 = seg_bus[vj*40+39 -: 10]; v_y1 = seg_bus[vj*40+29 -: 10];
                        v_x2 = seg_bus[vj*40+19 -: 10]; v_y2 = seg_bus[vj*40+ 9 -: 10];
                        if (v_cnx >= v_x1 && v_cnx <= v_x2 && v_cny >= v_y1 && v_cny <= v_y2)
                            v_hit = 1'b1;
                    end
                end
                if (!v_hit) begin
                    v_x1 = seg_bus[39 -: 10]; v_x2 = seg_bus[19 -: 10];
                    v_y1 = seg_bus[29 -: 10]; v_y2 = seg_bus[ 9 -: 10];
                    cone_bus[vi*20 +: 20] <= {(v_x1 + v_x2) >> 1, (v_y1 + v_y2) >> 1};
                end
            end
        end
    end
end

// ── Combinational Placement Validity Checker ──────────────────────────────
always @(*) begin : placement_checker
    integer ci, cj, ck;

    cone_ok    = {`MAX_CONES{1'b1}};
    coin_ok    = {`MAX_COINS{1'b1}};
    no_overlap = 1'b1;

    for (ci = 0; ci < `MAX_CONES; ci = ci + 1) begin
        if (ci < num_cones) begin
            c_cnx = cone_bus[ci*20+19 -: 10];
            c_cny = cone_bus[ci*20+ 9 -: 10];
            c_hit = 1'b0;
            for (cj = 0; cj < `MAX_SEGS; cj = cj + 1) begin
                if (cj < num_segs) begin
                    c_x1 = seg_bus[cj*40+39 -: 10]; c_y1 = seg_bus[cj*40+29 -: 10];
                    c_x2 = seg_bus[cj*40+19 -: 10]; c_y2 = seg_bus[cj*40+ 9 -: 10];
                    if (c_cnx >= c_x1 && c_cnx <= c_x2 && c_cny >= c_y1 && c_cny <= c_y2)
                        c_hit = 1'b1;
                end
            end
            cone_ok[ci] = c_hit;
        end
    end

    for (ci = 0; ci < `MAX_COINS; ci = ci + 1) begin
        if (ci < num_coins) begin
            c_px = coin_bus[ci*20+19 -: 10];
            c_py = coin_bus[ci*20+ 9 -: 10];
            c_hit = 1'b0;
            for (cj = 0; cj < `MAX_SEGS; cj = cj + 1) begin
                if (cj < num_segs) begin
                    c_x1 = seg_bus[cj*40+39 -: 10]; c_y1 = seg_bus[cj*40+29 -: 10];
                    c_x2 = seg_bus[cj*40+19 -: 10]; c_y2 = seg_bus[cj*40+ 9 -: 10];
                    if (c_px >= c_x1 && c_px <= c_x2 && c_py >= c_y1 && c_py <= c_y2)
                        c_hit = 1'b1;
                end
            end
            coin_ok[ci] = c_hit;

            for (ck = 0; ck < `MAX_CONES; ck = ck + 1) begin
                if (ck < num_cones) begin
                    c_cnx = cone_bus[ck*20+19 -: 10];
                    c_cny = cone_bus[ck*20+ 9 -: 10];
                    if (c_px == c_cnx && c_py == c_cny)
                        no_overlap = 1'b0;
                end
            end
        end
    end
end

endmodule