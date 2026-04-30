// collision_detector.v — Checks car corner pixels against track boundaries.
//
// Each frame (60 Hz), samples the 4 corners of the car bounding box.
// Corner pixel colors are provided by the track_renderer via color outputs.
// A green pixel (24'h00AA00) at any corner triggers collision.
// Also checks car center against all cone positions (4-px radius).
//
// NOTE: color sampling is done externally — the top level reads the rendered
// color at each corner coordinate and feeds it here as corner_color[3:0].

`include "track_data.vh"

module collision_detector (
    input  wire        clk50,
    input  wire        rst_n,
    input  wire        tick_60hz,
    // Car position
    input  wire [9:0]  car_x,
    input  wire [9:0]  car_y,
    // Color at the 4 corners sampled by top-level (1 = green/off-road)
    // corners: [0]=TL [1]=TR [2]=BL [3]=BR
    input  wire [3:0]  corner_offroad,
    // Collision output
    output reg         collision
);

// ── Cone hit check ────────────────────────────────────────────────────────
// Check if car center (car_x, car_y) is within 4 px radius of any cone.
reg [9:0] cone_cx [0:`NUM_CONES-1];
reg [9:0] cone_cy [0:`NUM_CONES-1];

initial begin
    cone_cx[0] = 10'd108; cone_cy[0] = 10'd135;
    cone_cx[1] = 10'd83;  cone_cy[1] = 10'd178;
    cone_cx[2] = 10'd117; cone_cy[2] = 10'd219;
    cone_cx[3] = 10'd210; cone_cy[3] = 10'd91;
    cone_cx[4] = 10'd400; cone_cy[4] = 10'd55;
    cone_cx[5] = 10'd580; cone_cy[5] = 10'd135;
    cone_cx[6] = 10'd580; cone_cy[6] = 10'd320;
    cone_cx[7] = 10'd420; cone_cy[7] = 10'd350;
    cone_cx[8] = 10'd170; cone_cy[8] = 10'd350;
    cone_cx[9] = 10'd50;  cone_cy[9] = 10'd260;
end

function automatic cone_hit;
    input [9:0] cx, cy;
    reg [10:0] dx, dy;
    reg [21:0] dist2;
    integer i;
    begin
        cone_hit = 1'b0;
        for (i = 0; i < `NUM_CONES; i = i + 1) begin
            dx = (cx >= cone_cx[i]) ? cx - cone_cx[i] : cone_cx[i] - cx;
            dy = (cy >= cone_cy[i]) ? cy - cone_cy[i] : cone_cy[i] - cy;
            dist2 = dx*dx + dy*dy;
            if (dist2 <= 22'd16) cone_hit = 1'b1;  // radius 4 → 4²=16
        end
    end
endfunction

// ── Collision register ─────────────────────────────────────────────────────
always @(posedge clk50) begin
    if (!rst_n) begin
        collision <= 1'b0;
    end else if (tick_60hz) begin
        collision <= (|corner_offroad) | cone_hit(car_x, car_y);
    end
end

endmodule
