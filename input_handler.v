// input_handler.v — DE2 switch and push-button input with 20 ms debounce.
//
// DE2 mapping:
//   SW[0]  → accelerate (level)
//   SW[1]  → brake / reverse (level)
//   KEY[0] → steer right (active-low, edge-detected)
//   KEY[1] → steer left  (active-low, edge-detected)
//   KEY[3] → start / reset (active-low, edge-detected)

module input_handler (
    input  wire       clk50,        // 50 MHz system clock
    input  wire       rst_n,        // active-low synchronous reset
    // Raw DE2 inputs (active levels as documented)
    input  wire [1:0] sw,           // sw[0]=accel, sw[1]=brake
    input  wire [3:0] key,          // active-low push buttons
    // Debounced outputs
    output reg        accel,        // SW[0] debounced level
    output reg        brake,        // SW[1] debounced level
    output reg        steer_left,   // KEY[0] single-cycle pulse
    output reg        steer_right,  // KEY[1] single-cycle pulse
    output reg        start_btn     // KEY[3] single-cycle pulse
);

// ── Debounce counter: 20 ms at 50 MHz = 1,000,000 cycles ─────────────────
localparam DEBOUNCE_MAX = 20'd1_000_000;

// Generic debounce cell (level signals)
task automatic debounce_level;
    input        raw;
    inout        stable;
    inout [19:0] cnt;
    begin
        if (raw == stable) begin
            cnt <= 20'd0;
        end else begin
            cnt <= cnt + 20'd1;
            if (cnt == DEBOUNCE_MAX - 1) begin
                stable <= raw;
                cnt    <= 20'd0;
            end
        end
    end
endtask

// Debounce state for SW[0], SW[1]
reg        sw0_stable, sw1_stable;
reg [19:0] sw0_cnt,    sw1_cnt;

always @(posedge clk50) begin
    if (!rst_n) begin
        sw0_stable <= 1'b0; sw0_cnt <= 20'd0;
        sw1_stable <= 1'b0; sw1_cnt <= 20'd0;
        accel      <= 1'b0;
        brake      <= 1'b0;
    end else begin
        debounce_level(sw[0], sw0_stable, sw0_cnt);
        debounce_level(sw[1], sw1_stable, sw1_cnt);
        accel <= sw0_stable;
        brake <= sw1_stable;
    end
end

// ── Edge-detect debounce for push buttons (active-low) ───────────────────
// We debounce the raw input, then detect falling edge for a single pulse.

reg [3:0] key_db;       // debounced key levels (1 = pressed)
reg [3:0] key_prev;     // previous debounced levels

// Per-key debounce counters and stable registers
reg [19:0] key_cnt [0:3];
reg        key_stable [0:3];

integer k;
always @(posedge clk50) begin
    if (!rst_n) begin
        for (k = 0; k < 4; k = k + 1) begin
            key_cnt[k]    <= 20'd0;
            key_stable[k] <= 1'b0;
        end
        key_db   <= 4'b0000;
        key_prev <= 4'b0000;
        steer_left  <= 1'b0;
        steer_right <= 1'b0;
        start_btn   <= 1'b0;
    end else begin
        // Debounce each key (key is active-low on DE2 → invert for active-high stable)
        for (k = 0; k < 4; k = k + 1) begin
            if (~key[k] == key_stable[k]) begin
                key_cnt[k] <= 20'd0;
            end else begin
                key_cnt[k] <= key_cnt[k] + 20'd1;
                if (key_cnt[k] == DEBOUNCE_MAX - 1) begin
                    key_stable[k] <= ~key[k];
                    key_cnt[k]    <= 20'd0;
                end
            end
            key_db[k] <= key_stable[k];
        end

        key_prev <= key_db;

        // steer_left/right: level (held high while key held down)
        // start_btn: single-cycle pulse on press
        steer_left  <= key_db[1];
        steer_right <= key_db[0];
        start_btn   <= key_db[3] & ~key_prev[3];
    end
end

endmodule