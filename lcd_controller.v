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
    output reg  [7:0]  LCD_DATA
);

assign LCD_RW = 1'b0;  // write-only

// ── Timing (50 MHz) ───────────────────────────────────────────────────────
localparam T_PWRUP   = 24'd2_500_000; // 50 ms
localparam T_4P1MS   = 24'd205_000;   // 4.1 ms
localparam T_100US   = 24'd5_000;     // 100 us
localparam T_40US    = 24'd2_000;     // 40 us
localparam T_CLEAR   = 24'd82_000;    // 1.64 ms
localparam T_SETUP   = 24'd50;        // 1 us data setup before EN rising
localparam T_E_PULSE = 24'd50;        // 1 us EN high

// ── Message ROM: 4 messages × 16 chars ───────────────────────────────────
// game_state: 0=IDLE 1=DRIVING 2=FAIL 3=PASS
function [7:0] msg_char;
    input [1:0] state;
    input [4:0] index;
    begin
        case (state)
            2'd0: begin
                case (index)
                    5'd0: msg_char = 8'h50;
                    5'd1: msg_char = 8'h52;
                    5'd2: msg_char = 8'h45;
                    5'd3: msg_char = 8'h53;
                    5'd4: msg_char = 8'h53;
                    5'd5: msg_char = 8'h20;
                    5'd6: msg_char = 8'h53;
                    5'd7: msg_char = 8'h54;
                    5'd8: msg_char = 8'h41;
                    5'd9: msg_char = 8'h52;
                    5'd10: msg_char = 8'h54;
                    default: msg_char = 8'h20;
                endcase
            end
            2'd1: begin
                case (index)
                    5'd0: msg_char = 8'h44;
                    5'd1: msg_char = 8'h52;
                    5'd2: msg_char = 8'h49;
                    5'd3: msg_char = 8'h56;
                    5'd4: msg_char = 8'h45;
                    5'd5: msg_char = 8'h20;
                    5'd6: msg_char = 8'h53;
                    5'd7: msg_char = 8'h41;
                    5'd8: msg_char = 8'h46;
                    5'd9: msg_char = 8'h45;
                    5'd10: msg_char = 8'h4C;
                    5'd11: msg_char = 8'h59;
                    default: msg_char = 8'h20;
                endcase
            end
            2'd2: begin
                case (index)
                    5'd0: msg_char = 8'h54;
                    5'd1: msg_char = 8'h45;
                    5'd2: msg_char = 8'h53;
                    5'd3: msg_char = 8'h54;
                    5'd4: msg_char = 8'h20;
                    5'd5: msg_char = 8'h46;
                    5'd6: msg_char = 8'h41;
                    5'd7: msg_char = 8'h49;
                    5'd8: msg_char = 8'h4C;
                    5'd9: msg_char = 8'h45;
                    5'd10: msg_char = 8'h44;
                    default: msg_char = 8'h20;
                endcase
            end
            default: begin
                case (index)
                    5'd0: msg_char = 8'h54;
                    5'd1: msg_char = 8'h45;
                    5'd2: msg_char = 8'h53;
                    5'd3: msg_char = 8'h54;
                    5'd4: msg_char = 8'h20;
                    5'd5: msg_char = 8'h50;
                    5'd6: msg_char = 8'h41;
                    5'd7: msg_char = 8'h53;
                    5'd8: msg_char = 8'h53;
                    5'd9: msg_char = 8'h45;
                    5'd10: msg_char = 8'h44;
                    default: msg_char = 8'h20;
                endcase
            end
        endcase
    end
endfunction

// ── Driver FSM ────────────────────────────────────────────────────────────
localparam ST_WAIT_PWR = 3'd0;
localparam ST_LOAD     = 3'd1;
localparam ST_SETUP    = 3'd2;
localparam ST_PULSE_HI = 3'd3;
localparam ST_PULSE_LO = 3'd4;
localparam ST_WAIT_CMD = 3'd5;
localparam ST_NEXT     = 3'd6;
localparam ST_IDLE     = 3'd7;

reg [2:0]  state;
reg [5:0]  step;
reg [23:0] wait_cnt;
reg [23:0] wait_target;
reg [7:0]  tx_byte;
reg [3:0]  tx_nibble;
reg        tx_rs;
reg        tx_full_byte;
reg        nibble_sel;      // 0=high nibble, 1=low nibble
reg [1:0]  disp_state;

always @(posedge clk50) begin
    if (!rst_n) begin
        state       <= ST_WAIT_PWR;
        step        <= 6'd0;
        wait_cnt    <= 24'd0;
        wait_target <= T_PWRUP;
        tx_byte     <= 8'h00;
        tx_nibble   <= 4'h0;
        tx_rs       <= 1'b0;
        tx_full_byte<= 1'b0;
        nibble_sel  <= 1'b0;
        disp_state  <= 2'd0;
        LCD_EN      <= 1'b0;
        LCD_RS      <= 1'b0;
        LCD_DATA    <= 8'h00;
    end else begin
        case (state)
            ST_WAIT_PWR: begin
                LCD_EN <= 1'b0;
                LCD_RS <= 1'b0;
                if (wait_cnt < T_PWRUP)
                    wait_cnt <= wait_cnt + 24'd1;
                else begin
                    wait_cnt <= 24'd0;
                    step     <= 6'd0;
                    state    <= ST_LOAD;
                end
            end

            ST_LOAD: begin
                nibble_sel <= 1'b0;
                case (step)
                    // HD44780 4-bit initialization handshake (high-nibble only)
                    6'd0: begin tx_rs <= 1'b0; tx_nibble <= 4'h3; tx_full_byte <= 1'b0; wait_target <= T_4P1MS; end
                    6'd1: begin tx_rs <= 1'b0; tx_nibble <= 4'h3; tx_full_byte <= 1'b0; wait_target <= T_100US; end
                    6'd2: begin tx_rs <= 1'b0; tx_nibble <= 4'h3; tx_full_byte <= 1'b0; wait_target <= T_100US; end
                    6'd3: begin tx_rs <= 1'b0; tx_nibble <= 4'h2; tx_full_byte <= 1'b0; wait_target <= T_100US; end

                    // Standard 4-bit setup commands
                    6'd4: begin tx_rs <= 1'b0; tx_byte <= 8'h28; tx_full_byte <= 1'b1; wait_target <= T_40US; end // 4-bit, 2-line
                    6'd5: begin tx_rs <= 1'b0; tx_byte <= 8'h0C; tx_full_byte <= 1'b1; wait_target <= T_40US; end // display on
                    6'd6: begin tx_rs <= 1'b0; tx_byte <= 8'h01; tx_full_byte <= 1'b1; wait_target <= T_CLEAR; end // clear
                    6'd7: begin tx_rs <= 1'b0; tx_byte <= 8'h06; tx_full_byte <= 1'b1; wait_target <= T_40US; end // entry mode
                    6'd8: begin tx_rs <= 1'b0; tx_byte <= 8'h80; tx_full_byte <= 1'b1; wait_target <= T_40US; end // line 1, col 0

                    // Line 1: message text
                    6'd9,6'd10,6'd11,6'd12,6'd13,6'd14,6'd15,6'd16,
                    6'd17,6'd18,6'd19,6'd20,6'd21,6'd22,6'd23,6'd24: begin
                        tx_rs       <= 1'b1;
                        tx_byte     <= msg_char(disp_state, step - 6'd9);
                        tx_full_byte<= 1'b1;
                        wait_target <= T_40US;
                    end

                    6'd25: begin tx_rs <= 1'b0; tx_byte <= 8'hC0; tx_full_byte <= 1'b1; wait_target <= T_40US; end // line 2, col 0

                    // Line 2: explicit spaces to clear any leftover power-on garbage
                    6'd26,6'd27,6'd28,6'd29,6'd30,6'd31,6'd32,6'd33,
                    6'd34,6'd35,6'd36,6'd37,6'd38,6'd39,6'd40,6'd41: begin
                        tx_rs       <= 1'b1;
                        tx_byte     <= 8'h20;
                        tx_full_byte<= 1'b1;
                        wait_target <= T_40US;
                    end

                    default: begin
                        state <= ST_IDLE;
                    end
                endcase

                if (state != ST_IDLE)
                    state <= ST_SETUP;
            end

            ST_SETUP: begin
                LCD_EN   <= 1'b0;
                LCD_RS   <= tx_rs;
                LCD_DATA <= {tx_full_byte ? (nibble_sel ? tx_byte[3:0] : tx_byte[7:4]) : tx_nibble, 4'h0};
                if (wait_cnt < T_SETUP)
                    wait_cnt <= wait_cnt + 24'd1;
                else begin
                    wait_cnt <= 24'd0;
                    state    <= ST_PULSE_HI;
                end
            end

            ST_PULSE_HI: begin
                LCD_EN   <= 1'b1;
                if (wait_cnt < T_E_PULSE)
                    wait_cnt <= wait_cnt + 24'd1;
                else begin
                    wait_cnt <= 24'd0;
                    state    <= ST_PULSE_LO;
                end
            end

            ST_PULSE_LO: begin
                LCD_EN <= 1'b0;
                if (wait_cnt < T_E_PULSE)
                    wait_cnt <= wait_cnt + 24'd1;
                else begin
                    wait_cnt <= 24'd0;
                    if (tx_full_byte && !nibble_sel) begin
                        nibble_sel <= 1'b1;
                        state      <= ST_SETUP;
                    end else begin
                        state      <= ST_WAIT_CMD;
                    end
                end
            end

            ST_WAIT_CMD: begin
                if (wait_cnt < wait_target)
                    wait_cnt <= wait_cnt + 24'd1;
                else begin
                    wait_cnt <= 24'd0;
                    state    <= ST_NEXT;
                end
            end

            ST_NEXT: begin
                if (step < 6'd41) begin
                    step  <= step + 6'd1;
                    state <= ST_LOAD;
                end else begin
                    state <= ST_IDLE;
                end
            end

            ST_IDLE: begin
                LCD_EN <= 1'b0;
                if (game_state != disp_state) begin
                    disp_state <= game_state;
                    step       <= 6'd8; // set DDRAM addr then rewrite line
                    state      <= ST_LOAD;
                end
            end

            default: state <= ST_WAIT_PWR;
        endcase
    end
end

endmodule
