// audio_controller.v — Buzzer/audio output for game events.
//
// Generates simple square-wave tones on DE2 AUD_ADCDAT / GPIO buzzer pin.
// For DE2, audio typically goes through the Wolfson WM8731 codec.
// This module drives a direct buzzer tone on GPIO (simplest approach for FPGA lab).
//
// Connect BUZZER_OUT to a piezoelectric buzzer on GPIO_0[0] (or similar).
//
// Tones:
//   DRIVING  — silent
//   FAIL     — 500 Hz continuous buzz (collision / fail tone)
//   PASS     — 880 Hz short jingle (3 beeps)

module audio_controller (
    input  wire       clk50,
    input  wire       rst_n,
    input  wire [1:0] game_state,  // 0=IDLE 1=DRIVING 2=FAIL 3=PASS
    output reg        buzzer_out   // connect to GPIO buzzer
);

// ── Frequency dividers ────────────────────────────────────────────────────
// 500 Hz tone: 50e6 / (500*2) = 50000 cycles per half-period
// 880 Hz tone: 50e6 / (880*2) = 28409 cycles per half-period
localparam HALF_500HZ = 17'd50_000;
localparam HALF_880HZ = 17'd28_409;

// ── Pass jingle: 3 beeps of 150 ms on, 100 ms off ────────────────────────
// At 50 MHz: 150 ms = 7,500,000 cycles; 100 ms = 5,000,000 cycles
localparam BEEP_ON  = 24'd7_500_000;
localparam BEEP_OFF = 24'd5_000_000;

reg [16:0] tone_cnt;
reg [23:0] jingle_cnt;
reg [1:0]  beep_num;    // 0, 1, 2
reg        beep_active;
reg        tone_bit;

always @(posedge clk50) begin
    if (!rst_n) begin
        tone_cnt   <= 17'd0;
        jingle_cnt <= 24'd0;
        beep_num   <= 2'd0;
        beep_active <= 1'b0;
        tone_bit   <= 1'b0;
        buzzer_out <= 1'b0;
    end else begin
        case (game_state)
            2'd0, 2'd1: begin  // IDLE or DRIVING — silent
                buzzer_out  <= 1'b0;
                tone_bit    <= 1'b0;
                tone_cnt    <= 17'd0;
                jingle_cnt  <= 24'd0;
                beep_num    <= 2'd0;
                beep_active <= 1'b1; // arm for first beep on PASS entry
            end

            2'd2: begin  // FAIL — 500 Hz continuous
                tone_cnt <= tone_cnt + 17'd1;
                if (tone_cnt >= HALF_500HZ) begin
                    tone_cnt   <= 17'd0;
                    tone_bit   <= ~tone_bit;
                end
                buzzer_out <= tone_bit;
            end

            2'd3: begin  // PASS — 3 × 880 Hz beeps
                if (beep_num < 2'd3) begin
                    jingle_cnt <= jingle_cnt + 24'd1;
                    if (beep_active) begin
                        // Tone on
                        tone_cnt <= tone_cnt + 17'd1;
                        if (tone_cnt >= HALF_880HZ) begin
                            tone_cnt <= 17'd0;
                            tone_bit <= ~tone_bit;
                        end
                        buzzer_out <= tone_bit;
                        if (jingle_cnt >= BEEP_ON) begin
                            jingle_cnt  <= 24'd0;
                            beep_active <= 1'b0;
                            tone_bit    <= 1'b0;
                        end
                    end else begin
                        // Gap between beeps
                        buzzer_out <= 1'b0;
                        if (jingle_cnt >= BEEP_OFF) begin
                            jingle_cnt  <= 24'd0;
                            beep_active <= 1'b1;
                            beep_num    <= beep_num + 2'd1;
                        end
                    end
                end else begin
                    buzzer_out <= 1'b0;  // jingle complete
                end
            end

            default: buzzer_out <= 1'b0;
        endcase
    end
end

endmodule
