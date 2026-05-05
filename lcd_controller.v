// lcd_controller.v — DE2 16×2 character LCD controller.
//
// Drives the Optrex 16207 LCD via 4-bit interface (DB[7:4]).
// Displays a message selected by game_state:
//   IDLE    → "PRESS START     "
//   DRIVING → "DRIVE SAFELY    "
//   FAIL    → "TEST FAILED     "
//   PASS    → "TEST PASSED     "
//
// Timing is derived from 50 MHz clock; no external timer needed.
// Init sequence follows Hitachi HD44780 / Optrex DE2 datasheet.

module lcd_controller (
    input  wire        clk50,
    input  wire        rst_n,
    input  wire [1:0]  game_state,   // 0=IDLE 1=DRIVING 2=FAIL 3=PASS
    // LCD pins (match DE2 pin names)
    output reg         LCD_EN,
    output reg         LCD_RS,
    output wire        LCD_RW,
    output reg  [7:4]  LCD_DATA
);

assign LCD_RW = 1'b0;  // write-only

// ── Timing ────────────────────────────────────────────────────────────────
// 50 MHz → each counter tick = 20 ns
// E-pulse high width ≥ 450 ns → 23 ticks
// Data setup/hold ensured by state machine waits

localparam WAIT_INIT   = 24'd2_500_000;  // 50 ms at 50 MHz
localparam WAIT_CMD    = 24'd200_000;    // 4 ms between init commands
localparam WAIT_ENABLE = 24'd25;         // 500 ns E-pulse

// ── Message ROM: 4 messages × 16 chars ───────────────────────────────────
// game_state: 0=IDLE 1=DRIVING 2=FAIL 3=PASS
reg [7:0] msg_rom [0:3][0:15];

initial begin
    // "PRESS START     "
    msg_rom[0][0]=8'h50; msg_rom[0][1]=8'h52; msg_rom[0][2]=8'h45;
    msg_rom[0][3]=8'h53; msg_rom[0][4]=8'h53; msg_rom[0][5]=8'h20;
    msg_rom[0][6]=8'h53; msg_rom[0][7]=8'h54; msg_rom[0][8]=8'h41;
    msg_rom[0][9]=8'h52; msg_rom[0][10]=8'h54; msg_rom[0][11]=8'h20;
    msg_rom[0][12]=8'h20; msg_rom[0][13]=8'h20; msg_rom[0][14]=8'h20; msg_rom[0][15]=8'h20;
    // "DRIVE MODE       "
    msg_rom[1][0]=8'h44; msg_rom[1][1]=8'h52; msg_rom[1][2]=8'h49;
    msg_rom[1][3]=8'h56; msg_rom[1][4]=8'h45; msg_rom[1][5]=8'h20;
    msg_rom[1][6]=8'h4D; msg_rom[1][7]=8'h4F; msg_rom[1][8]=8'h44;
    msg_rom[1][9]=8'h45; msg_rom[1][10]=8'h20; msg_rom[1][11]=8'h20;
    msg_rom[1][12]=8'h20; msg_rom[1][13]=8'h20; msg_rom[1][14]=8'h20; msg_rom[1][15]=8'h20;
    // "YOU FAILED      "
    msg_rom[2][0]=8'h54; msg_rom[2][1]=8'h45; msg_rom[2][2]=8'h53;
    msg_rom[2][3]=8'h20; msg_rom[2][4]=8'h46; msg_rom[2][5]=8'h41;
    msg_rom[2][6]=8'h49; msg_rom[2][7]=8'h4C; msg_rom[2][8]=8'h45;
    msg_rom[2][9]=8'h20; msg_rom[2][10]=8'h20; msg_rom[2][11]=8'h20;
    msg_rom[2][12]=8'h20; msg_rom[2][13]=8'h20; msg_rom[2][14]=8'h20; msg_rom[2][15]=8'h20;
    // "YOU PASSED      "
    msg_rom[3][0]=8'h54; msg_rom[3][1]=8'h45; msg_rom[3][2]=8'h53;
    msg_rom[3][3]=8'h20; msg_rom[3][4]=8'h50; msg_rom[3][5]=8'h41;
    msg_rom[3][6]=8'h53; msg_rom[3][7]=8'h53; msg_rom[3][8]=8'h45;
    msg_rom[3][9]=8'h20; msg_rom[3][10]=8'h20; msg_rom[3][11]=8'h20;
    msg_rom[3][12]=8'h20; msg_rom[3][13]=8'h20; msg_rom[3][14]=8'h20; msg_rom[3][15]=8'h20;
end

// ── State machine ─────────────────────────────────────────────────────────
localparam S_POWER_UP  = 4'd0;
localparam S_INIT_1    = 4'd1;
localparam S_INIT_2    = 4'd2;
localparam S_INIT_3    = 4'd3;
localparam S_INIT_4    = 4'd4;
localparam S_HOME      = 4'd5;
localparam S_WRITE_HI  = 4'd6;
localparam S_WRITE_LO  = 4'd7;
localparam S_ENABLE_HI = 4'd8;
localparam S_ENABLE_LO = 4'd9;
localparam S_NEXT_CHAR = 4'd10;
localparam S_DONE      = 4'd11;

reg [3:0]  state;
reg [23:0] wait_cnt;
reg [3:0]  char_idx;
reg [7:0]  cur_byte;
reg        send_hi;       // sending high nibble
reg [1:0]  prev_state;   // detect game_state change

always @(posedge clk50) begin
    if (!rst_n) begin
        state      <= S_POWER_UP;
        wait_cnt   <= 24'd0;
        LCD_EN     <= 1'b0;
        LCD_RS     <= 1'b0;
        LCD_DATA   <= 4'h0;
        char_idx   <= 4'd0;
        prev_state <= 2'd0;
    end else begin
        case (state)
            // ── 50 ms power-up wait ──────────────────────────────────
            S_POWER_UP: begin
                LCD_EN <= 1'b0; LCD_RS <= 1'b0;
                if (wait_cnt < WAIT_INIT)
                    wait_cnt <= wait_cnt + 24'd1;
                else begin
                    wait_cnt <= 24'd0;
                    state    <= S_INIT_1;
                end
            end

            // ── Function Set: 4-bit, 2-line, 5×8 font (send 0x28) ────
            S_INIT_1: begin
                LCD_RS   <= 1'b0;
                LCD_DATA <= 4'h2;
                LCD_EN   <= 1'b1;
                if (wait_cnt < WAIT_ENABLE) wait_cnt <= wait_cnt + 24'd1;
                else begin
                    LCD_EN <= 1'b0; wait_cnt <= 24'd0;
                    // Send low nibble 0x8
                    cur_byte <= 8'h28;
                    state    <= S_INIT_2;
                end
            end
            S_INIT_2: begin
                LCD_RS   <= 1'b0;
                LCD_DATA <= 4'h8;
                LCD_EN   <= 1'b1;
                if (wait_cnt < WAIT_ENABLE) wait_cnt <= wait_cnt + 24'd1;
                else begin
                    LCD_EN <= 1'b0; wait_cnt <= 24'd0;
                    state  <= S_INIT_3;
                end
            end

            // ── Display ON, cursor OFF (0x0C) ─────────────────────────
            S_INIT_3: begin
                LCD_RS <= 1'b0;
                if (wait_cnt < WAIT_CMD)
                    wait_cnt <= wait_cnt + 24'd1;
                else begin
                    wait_cnt <= 24'd0;
                    // 0x0C → high nibble 0x0, low nibble 0xC
                    LCD_DATA <= 4'h0; LCD_EN <= 1'b1;
                    state    <= S_INIT_4;
                end
            end
            S_INIT_4: begin
                if (wait_cnt == 24'd0) LCD_EN <= 1'b0;
                if (wait_cnt < WAIT_ENABLE)
                    wait_cnt <= wait_cnt + 24'd1;
                else begin
                    LCD_DATA <= 4'hC; LCD_EN <= 1'b1;
                    if (wait_cnt < WAIT_ENABLE*2)
                        wait_cnt <= wait_cnt + 24'd1;
                    else begin
                        LCD_EN <= 1'b0; wait_cnt <= 24'd0;
                        state  <= S_HOME;
                    end
                end
            end

            // ── Return home command (0x02) + begin writing message ─────
            S_HOME: begin
                LCD_RS   <= 1'b0;
                LCD_DATA <= 4'h0;
                LCD_EN   <= 1'b1;
                if (wait_cnt < WAIT_ENABLE) wait_cnt <= wait_cnt + 24'd1;
                else begin
                    LCD_DATA <= 4'h2; LCD_EN <= 1'b0;
                    if (wait_cnt < WAIT_ENABLE*2) wait_cnt <= wait_cnt + 24'd1;
                    else begin
                        LCD_EN   <= 1'b1;
                        if (wait_cnt < WAIT_ENABLE*3) wait_cnt <= wait_cnt + 24'd1;
                        else begin
                            LCD_EN   <= 1'b0;
                            wait_cnt <= 24'd0;
                            char_idx <= 4'd0;
                            state    <= S_WRITE_HI;
                        end
                    end
                end
            end

            // ── Write character high nibble ────────────────────────────
            S_WRITE_HI: begin
                cur_byte <= msg_rom[game_state][char_idx];
                LCD_RS   <= 1'b1;
                LCD_DATA <= msg_rom[game_state][char_idx][7:4];
                LCD_EN   <= 1'b1;
                if (wait_cnt < WAIT_ENABLE) wait_cnt <= wait_cnt + 24'd1;
                else begin
                    LCD_EN <= 1'b0; wait_cnt <= 24'd0;
                    state  <= S_WRITE_LO;
                end
            end

            // ── Write character low nibble ─────────────────────────────
            S_WRITE_LO: begin
                LCD_RS   <= 1'b1;
                LCD_DATA <= cur_byte[3:0];
                LCD_EN   <= 1'b1;
                if (wait_cnt < WAIT_ENABLE) wait_cnt <= wait_cnt + 24'd1;
                else begin
                    LCD_EN <= 1'b0; wait_cnt <= 24'd0;
                    state  <= S_NEXT_CHAR;
                end
            end

            // ── Advance to next character ──────────────────────────────
            S_NEXT_CHAR: begin
                if (char_idx < 4'd15) begin
                    char_idx <= char_idx + 4'd1;
                    state    <= S_WRITE_HI;
                end else begin
                    state <= S_DONE;
                end
            end

            // ── Done — wait for game_state change then re-send ─────────
            S_DONE: begin
                prev_state <= game_state;
                if (game_state != prev_state)
                    state <= S_HOME;
            end

            default: state <= S_POWER_UP;
        endcase
    end
end

endmodule
