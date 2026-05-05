// coin_collector.v — Tracks which coins have been collected and total count.
//
// Each tick_60hz, the car centre is compared against every active coin.
// If distance² ≤ COLLECT_R² the coin is marked collected (bitmask) and
// the coin_count is incremented.  Everything resets on rst_n low.
//
// coin_bus[i*20 +: 20] = {cx[9:0], cy[9:0]}
// collected[i]         = 1 once coin i has been picked up
// coin_count           = total coins collected this run (0–15)

`include "track_data.vh"

module coin_collector (
    input  wire        clk50,
    input  wire        rst_n,
    input  wire        tick_60hz,
    input  wire        game_active,
    // Car position
    input  wire [9:0]  car_x,
    input  wire [9:0]  car_y,
    // Coin bus from track_gen
    input  wire [(`MAX_COINS*20)-1:0] coin_bus,
    input  wire [3:0]                 num_coins,
    // Outputs
    output reg  [`MAX_COINS-1:0]      collected,   // bitmask
    output reg  [3:0]                 coin_count   // 0–MAX_COINS
);

// Collect radius: 10 px → dist² ≤ 100
localparam COLLECT_R2 = 22'd100;

integer i;
reg [10:0] dx, dy;
reg [21:0] dist2;
reg [9:0]  ccx, ccy;

always @(posedge clk50) begin
    if (!rst_n) begin
        collected  <= {`MAX_COINS{1'b0}};
        coin_count <= 4'd0;
    end else if (!game_active) begin
        // Keep count visible between rounds but clear on full reset only.
        // Coins re-arm when track_gen reloads (rst_n pulse).
        collected  <= {`MAX_COINS{1'b0}};
        coin_count <= 4'd0;
    end else if (tick_60hz) begin
        for (i = 0; i < `MAX_COINS; i = i + 1) begin
            if (i < num_coins && !collected[i]) begin
                ccx   = coin_bus[i*20+19 -: 10];
                ccy   = coin_bus[i*20+ 9 -: 10];
                dx    = (car_x >= ccx) ? car_x - ccx : ccx - car_x;
                dy    = (car_y >= ccy) ? car_y - ccy : ccy - car_y;
                dist2 = dx*dx + dy*dy;
                if (dist2 <= COLLECT_R2) begin
                    collected[i] <= 1'b1;
                    coin_count   <= coin_count + 4'd1;
                end
            end
        end
    end
end

endmodule