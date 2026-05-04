// track_gen.v — Procedural track generator for GEL372 Driving Test.
//
// On every reset the module uses a free-running 16-bit LFSR to pick one of
// four hand-crafted rectangular-segment track layouts.  All road geometry is
// axis-aligned rectangles so the on-track test is pure box comparisons —
// no cross-products, no rounded corners.
//
// Road model: up to MAX_SEGS horizontal/vertical strips, each described by
//   {x1[9:0], y1[9:0], x2[9:0], y2[9:0]}  (inclusive pixel bounds).
// The union of all strips is drivable road.
//
// Cones: up to MAX_CONES positions {cx[9:0], cy[9:0]}.
//
// Buildings: up to MAX_BLDGS rectangles {bx[9:0], by[9:0], bw[7:0], bh[7:0]}.
//
// All arrays are exported as flat packed buses so they can be wired into
// track_renderer.v and collision_detector.v without dynamic indexing issues.
//
// Bus packing:
//   seg_bus  : MAX_SEGS  × 40 bits  [i*40 +: 40] = {x1,y1,x2,y2}
//   cone_bus : MAX_CONES × 20 bits  [i*20 +: 20] = {cx,cy}
//   bldg_bus : MAX_BLDGS × 36 bits  [i*36 +: 36] = {bx,by,bw,bh}
//   num_segs, num_cones, num_bldgs  — actual counts (≤ MAX)

`include "track_data.vh"

module track_gen (
    input  wire        clk50,
    input  wire        rst_n,          // active-low; latch new layout on rising edge
    // Road segments
    output reg  [(`MAX_SEGS *40)-1:0]  seg_bus,
    output reg  [3:0]                  num_segs,
    // Cones
    output reg  [(`MAX_CONES*20)-1:0]  cone_bus,
    output reg  [3:0]                  num_cones,
    // Buildings
    output reg  [(`MAX_BLDGS*36)-1:0]  bldg_bus,
    output reg  [3:0]                  num_bldgs
);

// ── Free-running LFSR (16-bit Fibonacci, taps 16,15,13,4) ────────────────
// Runs continuously; value is sampled on reset release to pick a layout.
reg [15:0] lfsr;
always @(posedge clk50) begin
    lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[14] ^ lfsr[12] ^ lfsr[3]};
end

// ── Helper macro: pack one segment into seg_bus ───────────────────────────
// Called inside the always block with explicit index
`define SEG(i,X1,Y1,X2,Y2) \
    seg_bus[(i)*40 +: 40] <= {10'd``X1, 10'd``Y1, 10'd``X2, 10'd``Y2}

`define CONE(i,CX,CY) \
    cone_bus[(i)*20 +: 20] <= {10'd``CX, 10'd``CY}

`define BLDG(i,BX,BY,BW,BH) \
    bldg_bus[(i)*36 +: 36] <= {10'd``BX, 10'd``BY, 8'd``BW, 8'd``BH}

// ── rst_n rising-edge detector ────────────────────────────────────────────
reg rst_prev;
always @(posedge clk50) rst_prev <= rst_n;
wire load_track = rst_n & ~rst_prev;   // one-cycle pulse on reset release

// ── Layout selection and load ─────────────────────────────────────────────
// Track road width is 50 px; start bay is fixed at x=[20..70], y=[310..380].
// finish line is fixed at y=150, x=[20..70] (left corridor heading north).
//
// All four layouts share:
//   Seg 0  — vertical left corridor  x=[20..70],  y=[150..380]  (start+finish bay)
// Then each layout routes differently across the screen before coming back.

always @(posedge clk50) begin
    if (load_track) begin
        // Zero out buses
        seg_bus  <= 0;
        cone_bus <= 0;
        bldg_bus <= 0;

        case (lfsr[1:0])   // 2 bits → 4 layouts

            // ═══════════════════════════════════════════════════════════════
            // LAYOUT 0 — clockwise outer loop with inner detour
            // ═══════════════════════════════════════════════════════════════
            2'd0: begin
                num_segs  <= 4'd10;
                num_cones <= 4'd8;
                num_bldgs <= 4'd6;

                // Seg 0: left vertical corridor (start+finish)
                seg_bus[0*40 +: 40]  <= {10'd20,  10'd130, 10'd70,  10'd400};
                // Seg 1: top horizontal — go right across top
                seg_bus[1*40 +: 40]  <= {10'd20,  10'd130, 10'd590, 10'd180};
                // Seg 2: right vertical — go down right side
                seg_bus[2*40 +: 40]  <= {10'd540, 10'd130, 10'd590, 10'd400};
                // Seg 3: bottom horizontal — go left partway
                seg_bus[3*40 +: 40]  <= {10'd20,  10'd350, 10'd590, 10'd400};
                // Seg 4: mid horizontal detour top
                seg_bus[4*40 +: 40]  <= {10'd200, 10'd220, 10'd500, 10'd270};
                // Seg 5: detour right vertical connector
                seg_bus[5*40 +: 40]  <= {10'd450, 10'd180, 10'd500, 10'd270};
                // Seg 6: detour left vertical connector
                seg_bus[6*40 +: 40]  <= {10'd200, 10'd180, 10'd250, 10'd270};
                // Seg 7: mid horizontal detour bottom
                seg_bus[7*40 +: 40]  <= {10'd200, 10'd270, 10'd500, 10'd320};
                // Seg 8: connector top-left → detour
                seg_bus[8*40 +: 40]  <= {10'd70,  10'd180, 10'd250, 10'd230};
                // Seg 9: connector bottom → left corridor
                seg_bus[9*40 +: 40]  <= {10'd70,  10'd320, 10'd250, 10'd370};

                // Cones at turn points
                cone_bus[0*20 +: 20] <= {10'd70,  10'd155};   // start of top turn
                cone_bus[1*20 +: 20] <= {10'd565, 10'd155};   // top-right corner
                cone_bus[2*20 +: 20] <= {10'd565, 10'd375};   // bottom-right corner
                cone_bus[3*20 +: 20] <= {10'd70,  10'd375};   // bottom-left corner
                cone_bus[4*20 +: 20] <= {10'd225, 10'd205};   // detour entry top
                cone_bus[5*20 +: 20] <= {10'd475, 10'd205};   // detour far top
                cone_bus[6*20 +: 20] <= {10'd475, 10'd295};   // detour far bottom
                cone_bus[7*20 +: 20] <= {10'd225, 10'd295};   // detour entry bottom

                // Buildings in off-road zones
                bldg_bus[0*36 +: 36] <= {10'd100, 10'd30,  8'd80, 8'd90};
                bldg_bus[1*36 +: 36] <= {10'd250, 10'd30,  8'd80, 8'd90};
                bldg_bus[2*36 +: 36] <= {10'd400, 10'd30,  8'd80, 8'd90};
                bldg_bus[3*36 +: 36] <= {10'd100, 10'd290, 8'd70, 8'd40};
                bldg_bus[4*36 +: 36] <= {10'd280, 10'd290, 8'd60, 8'd40};
                bldg_bus[5*36 +: 36] <= {10'd370, 10'd290, 8'd60, 8'd40};
            end

            // ═══════════════════════════════════════════════════════════════
            // LAYOUT 1 — S-curve / slalom down the middle
            // ═══════════════════════════════════════════════════════════════
            2'd1: begin
                num_segs  <= 4'd9;
                num_cones <= 4'd8;
                num_bldgs <= 4'd6;

                // Seg 0: left vertical (start+finish)
                seg_bus[0*40 +: 40]  <= {10'd20,  10'd130, 10'd70,  10'd400};
                // Seg 1: first horizontal shelf — go right from top of left corridor
                seg_bus[1*40 +: 40]  <= {10'd20,  10'd130, 10'd350, 10'd185};
                // Seg 2: mid-left vertical — go down to mid screen
                seg_bus[2*40 +: 40]  <= {10'd300, 10'd185, 10'd350, 10'd310};
                // Seg 3: mid horizontal — go right
                seg_bus[3*40 +: 40]  <= {10'd300, 10'd260, 10'd590, 10'd310};
                // Seg 4: right vertical — go down
                seg_bus[4*40 +: 40]  <= {10'd540, 10'd310, 10'd590, 10'd420};
                // Seg 5: bottom horizontal — go left
                seg_bus[5*40 +: 40]  <= {10'd20,  10'd370, 10'd590, 10'd420};
                // Seg 6: left vertical extension back to start
                seg_bus[6*40 +: 40]  <= {10'd20,  10'd370, 10'd70,  10'd400};
                // Seg 7: top-right extension
                seg_bus[7*40 +: 40]  <= {10'd300, 10'd130, 10'd590, 10'd185};
                // Seg 8: top-right vertical connector
                seg_bus[8*40 +: 40]  <= {10'd540, 10'd185, 10'd590, 10'd310};

                cone_bus[0*20 +: 20] <= {10'd70,  10'd157};
                cone_bus[1*20 +: 20] <= {10'd325, 10'd157};
                cone_bus[2*20 +: 20] <= {10'd565, 10'd157};
                cone_bus[3*20 +: 20] <= {10'd325, 10'd285};
                cone_bus[4*20 +: 20] <= {10'd565, 10'd335};
                cone_bus[5*20 +: 20] <= {10'd325, 10'd395};
                cone_bus[6*20 +: 20] <= {10'd70,  10'd395};
                cone_bus[7*20 +: 20] <= {10'd450, 10'd235};

                bldg_bus[0*36 +: 36] <= {10'd100, 10'd30,  8'd80, 8'd90};
                bldg_bus[1*36 +: 36] <= {10'd300, 10'd30,  8'd80, 8'd90};
                bldg_bus[2*36 +: 36] <= {10'd100, 10'd200, 8'd60, 8'd50};
                bldg_bus[3*36 +: 36] <= {10'd400, 10'd200, 8'd60, 8'd50};
                bldg_bus[4*36 +: 36] <= {10'd100, 10'd310, 8'd60, 8'd50};
                bldg_bus[5*36 +: 36] <= {10'd180, 10'd310, 8'd60, 8'd50};
            end

            // ═══════════════════════════════════════════════════════════════
            // LAYOUT 2 — figure-eight / cross-pattern
            // ═══════════════════════════════════════════════════════════════
            2'd2: begin
                num_segs  <= 4'd10;
                num_cones <= 4'd8;
                num_bldgs <= 4'd6;

                // Seg 0: left vertical (start+finish)
                seg_bus[0*40 +: 40]  <= {10'd20,  10'd130, 10'd70,  10'd400};
                // Seg 1: upper-left horizontal
                seg_bus[1*40 +: 40]  <= {10'd20,  10'd130, 10'd360, 10'd180};
                // Seg 2: upper-right horizontal
                seg_bus[2*40 +: 40]  <= {10'd310, 10'd130, 10'd590, 10'd180};
                // Seg 3: right vertical top section
                seg_bus[3*40 +: 40]  <= {10'd540, 10'd130, 10'd590, 10'd280};
                // Seg 4: center horizontal band
                seg_bus[4*40 +: 40]  <= {10'd20,  10'd240, 10'd590, 10'd290};
                // Seg 5: left vertical lower
                seg_bus[5*40 +: 40]  <= {10'd20,  10'd240, 10'd70,  10'd400};
                // Seg 6: right vertical lower
                seg_bus[6*40 +: 40]  <= {10'd540, 10'd240, 10'd590, 10'd400};
                // Seg 7: lower-left horizontal
                seg_bus[7*40 +: 40]  <= {10'd20,  10'd350, 10'd310, 10'd400};
                // Seg 8: lower-right horizontal
                seg_bus[8*40 +: 40]  <= {10'd310, 10'd350, 10'd590, 10'd400};
                // Seg 9: center vertical crossing
                seg_bus[9*40 +: 40]  <= {10'd310, 10'd130, 10'd360, 10'd400};

                cone_bus[0*20 +: 20] <= {10'd70,  10'd155};
                cone_bus[1*20 +: 20] <= {10'd335, 10'd155};
                cone_bus[2*20 +: 20] <= {10'd565, 10'd155};
                cone_bus[3*20 +: 20] <= {10'd565, 10'd265};
                cone_bus[4*20 +: 20] <= {10'd335, 10'd265};
                cone_bus[5*20 +: 20] <= {10'd70,  10'd265};
                cone_bus[6*20 +: 20] <= {10'd70,  10'd375};
                cone_bus[7*20 +: 20] <= {10'd565, 10'd375};

                bldg_bus[0*36 +: 36] <= {10'd100, 10'd30,  8'd80, 8'd90};
                bldg_bus[1*36 +: 36] <= {10'd400, 10'd30,  8'd80, 8'd90};
                bldg_bus[2*36 +: 36] <= {10'd100, 10'd195, 8'd60, 8'd35};
                bldg_bus[3*36 +: 36] <= {10'd400, 10'd195, 8'd60, 8'd35};
                bldg_bus[4*36 +: 36] <= {10'd100, 10'd310, 8'd80, 8'd30};
                bldg_bus[5*36 +: 36] <= {10'd400, 10'd310, 8'd80, 8'd30};
            end

            // ═══════════════════════════════════════════════════════════════
            // LAYOUT 3 — spiral / nested rectangles
            // ═══════════════════════════════════════════════════════════════
            2'd3: begin
                num_segs  <= 4'd12;
                num_cones <= 4'd8;
                num_bldgs <= 4'd6;

                // Seg 0: left vertical (start+finish)
                seg_bus[0*40 +: 40]  <= {10'd20,  10'd130, 10'd70,  10'd400};
                // Outer ring
                // Seg 1: outer top
                seg_bus[1*40 +: 40]  <= {10'd20,  10'd130, 10'd590, 10'd180};
                // Seg 2: outer right
                seg_bus[2*40 +: 40]  <= {10'd540, 10'd130, 10'd590, 10'd400};
                // Seg 3: outer bottom
                seg_bus[3*40 +: 40]  <= {10'd20,  10'd350, 10'd590, 10'd400};
                // Inner ring entry — from left corridor into inner top
                // Seg 4: inner top
                seg_bus[4*40 +: 40]  <= {10'd100, 10'd210, 10'd490, 10'd260};
                // Seg 5: inner right
                seg_bus[5*40 +: 40]  <= {10'd440, 10'd210, 10'd490, 10'd330};
                // Seg 6: inner bottom
                seg_bus[6*40 +: 40]  <= {10'd100, 10'd280, 10'd490, 10'd330};
                // Seg 7: inner left
                seg_bus[7*40 +: 40]  <= {10'd100, 10'd210, 10'd150, 10'd330};
                // Connectors outer ↔ inner
                // Seg 8: top-left connector  outer→inner
                seg_bus[8*40 +: 40]  <= {10'd70,  10'd180, 10'd150, 10'd260};
                // Seg 9: top-right connector outer→inner
                seg_bus[9*40 +: 40]  <= {10'd440, 10'd180, 10'd540, 10'd260};
                // Seg 10: bottom-left connector outer→inner
                seg_bus[10*40 +: 40] <= {10'd70,  10'd280, 10'd150, 10'd355};
                // Seg 11: bottom-right connector outer→inner
                seg_bus[11*40 +: 40] <= {10'd440, 10'd280, 10'd540, 10'd355};

                cone_bus[0*20 +: 20] <= {10'd70,  10'd155};
                cone_bus[1*20 +: 20] <= {10'd565, 10'd155};
                cone_bus[2*20 +: 20] <= {10'd565, 10'd375};
                cone_bus[3*20 +: 20] <= {10'd70,  10'd375};
                cone_bus[4*20 +: 20] <= {10'd125, 10'd235};
                cone_bus[5*20 +: 20] <= {10'd465, 10'd235};
                cone_bus[6*20 +: 20] <= {10'd465, 10'd305};
                cone_bus[7*20 +: 20] <= {10'd125, 10'd305};

                bldg_bus[0*36 +: 36] <= {10'd170, 10'd30,  8'd60, 8'd90};
                bldg_bus[1*36 +: 36] <= {10'd320, 10'd30,  8'd60, 8'd90};
                bldg_bus[2*36 +: 36] <= {10'd470, 10'd30,  8'd60, 8'd90};
                bldg_bus[3*36 +: 36] <= {10'd200, 10'd235, 8'd80, 8'd40};
                bldg_bus[4*36 +: 36] <= {10'd300, 10'd235, 8'd80, 8'd40};
                bldg_bus[5*36 +: 36] <= {10'd200, 10'd420, 8'd80, 8'd50};
            end
        endcase
    end
end

endmodule