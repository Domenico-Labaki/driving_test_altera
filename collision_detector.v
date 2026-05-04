// collision_detector.v — Checks car position against track and cones.
//
// Off-road detection: corner_offroad bits come from corner_probe modules
// in the top level — those still sample is_on_track via the seg_bus.
// Cone detection: uses the cone_bus from track_gen.
//
// Collision triggers on:
//   • Any car corner pixel that is off-road (corner_offroad[3:0])
//   • Car centre within Euclidean radius 6 of any cone

`include "track_data.vh"

module collision_detector (
    input  wire        clk50,
    input  wire        rst_n,
    input  wire        tick_60hz,
    // Car position
    input  wire [9:0]  car_x,
    input  wire [9:0]  car_y,
    // Off-road corner flags (set by corner_probe in top level)
    input  wire [3:0]  corner_offroad,
    // Cone bus from track_gen
    input  wire [(`MAX_CONES*20)-1:0] cone_bus,
    input  wire [3:0]                 num_cones,
    // Collision output
    output reg         collision
);

// ── Cone hit: Euclidean radius 6 (dist² ≤ 36) ───────────────────────────
function automatic cone_hit;
    input [9:0] cx, cy;
    input [(`MAX_CONES*20)-1:0] cbus;
    input [3:0] ncone;
    integer i;
    reg [10:0] dx, dy;
    reg [21:0] dist2;
    reg [9:0]  ccx, ccy;
    begin
        cone_hit = 1'b0;
        for (i = 0; i < `MAX_CONES; i = i + 1) begin
            if (i < ncone) begin
                ccx   = cbus[i*20+19 -: 10];
                ccy   = cbus[i*20+ 9 -: 10];
                dx    = (cx >= ccx) ? cx - ccx : ccx - cx;
                dy    = (cy >= ccy) ? cy - ccy : ccy - cy;
                dist2 = dx*dx + dy*dy;
                if (dist2 <= 22'd36) cone_hit = 1'b1;  // radius 6
            end
        end
    end
endfunction

always @(posedge clk50) begin
    if (!rst_n) begin
        collision <= 1'b0;
    end else if (tick_60hz) begin
        collision <= (|corner_offroad) | cone_hit(car_x, car_y, cone_bus, num_cones);
    end
end

endmodule