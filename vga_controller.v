// vga_controller.v — VGA sync generator for 640×480 @ 60 Hz
// Pixel clock: 25 MHz (derived from 50 MHz system clock via /2 divider)
// Timing values per VESA 640×480 @60 Hz standard.
//
// Outputs:
//   hsync, vsync   — active-low sync pulses
//   px [9:0]       — current pixel column (0 = first active pixel)
//   py [9:0]       — current pixel row    (0 = first active row)
//   active         — high when in visible area

module vga_controller (
    input  wire        clk50,   // 50 MHz system clock
    input  wire        rst_n,   // active-low synchronous reset
    output reg         hsync,
    output reg         vsync,
    output reg  [9:0]  px,
    output reg  [9:0]  py,
    output wire        active,
    output wire        pclk     // 25 MHz pixel clock (for downstream modules)
);

// ── Pixel-clock divider ──────────────────────────────────────────────────
reg clk25;
always @(posedge clk50) begin
    if (!rst_n) clk25 <= 1'b0;
    else        clk25 <= ~clk25;
end
assign pclk = clk25;

// ── Horizontal timing (pixels at 25 MHz) ────────────────────────────────
//   Visible: 640   Front porch: 16   Sync: 96   Back porch: 48   Total: 800
localparam H_VISIBLE    = 640;
localparam H_FP         = 16;
localparam H_SYNC       = 96;
localparam H_BP         = 48;
localparam H_TOTAL      = 800;
localparam H_SYNC_START = H_VISIBLE + H_FP;       // 656
localparam H_SYNC_END   = H_SYNC_START + H_SYNC;  // 752

// ── Vertical timing (lines) ──────────────────────────────────────────────
//   Visible: 480   Front porch: 10   Sync: 2   Back porch: 33   Total: 525
localparam V_VISIBLE    = 480;
localparam V_FP         = 10;
localparam V_SYNC       = 2;
localparam V_BP         = 33;
localparam V_TOTAL      = 525;
localparam V_SYNC_START = V_VISIBLE + V_FP;       // 490
localparam V_SYNC_END   = V_SYNC_START + V_SYNC;  // 492

// ── Counters ─────────────────────────────────────────────────────────────
reg [9:0] hcnt;   // horizontal counter [0, 799]
reg [9:0] vcnt;   // vertical counter   [0, 524]

always @(posedge clk25) begin
    if (!rst_n) begin
        hcnt  <= 10'd0;
        vcnt  <= 10'd0;
        hsync <= 1'b1;
        vsync <= 1'b1;
        px    <= 10'd0;
        py    <= 10'd0;
    end else begin
        // Horizontal counter
        if (hcnt == H_TOTAL - 1) begin
            hcnt <= 10'd0;
            if (vcnt == V_TOTAL - 1)
                vcnt <= 10'd0;
            else
                vcnt <= vcnt + 10'd1;
        end else begin
            hcnt <= hcnt + 10'd1;
        end

        // Sync pulses (active low)
        hsync <= ~(hcnt >= H_SYNC_START && hcnt < H_SYNC_END);
        vsync <= ~(vcnt >= V_SYNC_START && vcnt < V_SYNC_END);

        // Pixel coordinates — valid only during active region
        px <= (hcnt < H_VISIBLE) ? hcnt : 10'd0;
        py <= (vcnt < V_VISIBLE) ? vcnt : 10'd0;
    end
end

assign active = (hcnt < H_VISIBLE) && (vcnt < V_VISIBLE);

endmodule
