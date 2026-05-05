// audio_controller.v ? WM8731 codec audio output for game events.
//
// Drives the DE2 audio CODEC directly through the WM8731 interface.
// The codec is initialized over I2C, then PCM samples are streamed to DAC.

module audio_controller (
    input  wire       clk50,
    input  wire       rst_n,
    input  wire [1:0] game_state,  // 0=MENU 1=DRIVING 2=FAIL 3=PASS
    input  wire       crash,
    input  wire       coin,
    input  wire       honk,
    input  wire       AUD_ADCLRCK,
    input  wire       AUD_ADCDAT,
    output wire       AUD_XCK,
    output wire       AUD_BCLK,
    output reg        AUD_DACLRCK,
    output reg        AUD_DACDAT,
    output wire       I2C_SCLK,
    inout  wire       I2C_SDAT
);

localparam signed [15:0] AMP = 16'sd12000;
localparam [15:0] HALF_440  = 16'd55;
localparam [15:0] HALF_500  = 16'd49;
localparam [15:0] HALF_880  = 16'd28;
localparam [15:0] HALF_1000 = 16'd24;

localparam [15:0] COIN_FRAMES  = 16'd3000;
localparam [15:0] CRASH_FRAMES = 16'd5000;
localparam [15:0] WIN_ON_FRAMES  = 16'd4000;
localparam [15:0] WIN_OFF_FRAMES = 16'd2500;

localparam MODE_SILENT = 3'd0;
localparam MODE_HONK   = 3'd1;
localparam MODE_COIN   = 3'd2;
localparam MODE_CRASH  = 3'd3;
localparam MODE_WIN    = 3'd4;

// -------------------------------------------------------------------------
// Clock dividers
// -------------------------------------------------------------------------
reg [4:0] audio_div;
always @(posedge clk50) begin
    if (!rst_n) audio_div <= 5'd0;
    else        audio_div <= audio_div + 5'd1;
end

assign AUD_XCK  = audio_div[1];
assign AUD_BCLK = audio_div[4];

wire bit_tick = (audio_div == 5'd31);  // one DAC bit every BCLK period

// -------------------------------------------------------------------------
// WM8731 I2C initialization
// -------------------------------------------------------------------------
function [15:0] wm8731_cmd;
    input [3:0] idx;
    begin
        case (idx)
            4'd0: wm8731_cmd = 16'h0F00; // reset
            4'd1: wm8731_cmd = 16'h0017; // left line in
            4'd2: wm8731_cmd = 16'h0217; // right line in
            4'd3: wm8731_cmd = 16'h0479; // left headphone out
            4'd4: wm8731_cmd = 16'h0679; // right headphone out
            4'd5: wm8731_cmd = 16'h0812; // analog path control
            4'd6: wm8731_cmd = 16'h0A00; // digital path control
            4'd7: wm8731_cmd = 16'h0C00; // power down control
            4'd8: wm8731_cmd = 16'h0E02; // digital audio interface: I2S, slave
            4'd9: wm8731_cmd = 16'h1000; // sample rate control
            4'd10: wm8731_cmd = 16'h1201; // active control
            default: wm8731_cmd = 16'h1201;
        endcase
    end
endfunction

reg        i2c_scl_r;
reg        i2c_sda_drive_low;
assign I2C_SCLK = i2c_scl_r;
assign I2C_SDAT = i2c_sda_drive_low ? 1'b0 : 1'bz;

reg [15:0] i2c_wait_cnt;
reg [8:0]  i2c_div;
reg [2:0]  i2c_state;
reg [3:0]  cmd_index;
reg [1:0]  byte_sel;
reg [2:0]  bit_sel;
reg [7:0]  current_byte;
reg [15:0] current_cmd;
reg        codec_ready;

localparam I2C_WAIT   = 3'd0;
localparam I2C_START  = 3'd1;
localparam I2C_BIT_LO = 3'd2;
localparam I2C_BIT_HI = 3'd3;
localparam I2C_ACK_LO = 3'd4;
localparam I2C_ACK_HI = 3'd5;
localparam I2C_STOP   = 3'd6;
localparam I2C_DONE   = 3'd7;

wire i2c_tick = (i2c_div == 9'd249); // ~100 kHz service rate

// -------------------------------------------------------------------------
// Audio event state
// -------------------------------------------------------------------------
reg [15:0] coin_frames_left;
reg [15:0] crash_frames_left;
reg        win_done;
reg        win_gap;
reg [1:0]  win_beep;
reg [15:0] win_count;
reg [15:0] win_tone_count;
reg        win_phase;

reg [2:0]  mode;
reg [15:0] tone_count;
reg [15:0] current_sample;
reg        tone_phase;
reg [4:0]  bit_index;
reg [15:0] left_shift;
reg [15:0] right_shift;

wire [2:0] requested_mode =
    (game_state == 2'd3 && !win_done) ? MODE_WIN   :
    (crash_frames_left != 16'd0)      ? MODE_CRASH :
    (coin_frames_left != 16'd0)       ? MODE_COIN   :
    (honk)                            ? MODE_HONK   :
                                       MODE_SILENT;

always @(posedge clk50) begin
    if (!rst_n) begin
        i2c_wait_cnt      <= 16'd0;
        i2c_div           <= 9'd0;
        i2c_state         <= I2C_WAIT;
        cmd_index         <= 4'd0;
        byte_sel          <= 2'd0;
        bit_sel           <= 3'd7;
        current_byte      <= 8'h34;
        current_cmd       <= wm8731_cmd(4'd0);
        codec_ready       <= 1'b0;
        i2c_scl_r         <= 1'b1;
        i2c_sda_drive_low <= 1'b0;

        coin_frames_left  <= 16'd0;
        crash_frames_left <= 16'd0;
        win_done          <= 1'b0;
        win_gap           <= 1'b0;
        win_beep          <= 2'd0;
        win_count         <= 16'd0;
        win_tone_count    <= 16'd0;
        win_phase         <= 1'b0;

        mode              <= MODE_SILENT;
        tone_count        <= 16'd0;
        current_sample    <= 16'sd0;
        tone_phase        <= 1'b0;
        bit_index         <= 5'd0;
        left_shift        <= 16'd0;
        right_shift       <= 16'd0;
        AUD_DACLRCK       <= 1'b0;
        AUD_DACDAT        <= 1'b0;
    end else begin
        // Capture one-cycle pulses from the game logic.
        if (coin)  coin_frames_left  <= COIN_FRAMES;
        else if (coin_frames_left != 16'd0)  coin_frames_left <= coin_frames_left - 16'd1;

        if (crash) crash_frames_left <= CRASH_FRAMES;
        else if (crash_frames_left != 16'd0) crash_frames_left <= crash_frames_left - 16'd1;

        // Win jingle state machine.
        if (game_state != 2'd3) begin
            win_done       <= 1'b0;
            win_gap        <= 1'b0;
            win_beep       <= 2'd0;
            win_count      <= 16'd0;
            win_tone_count <= 16'd0;
            win_phase      <= 1'b0;
        end else if (!win_done) begin
            if (!win_gap) begin
                if (win_tone_count >= HALF_880 - 16'd1) begin
                    win_tone_count <= 16'd0;
                    win_phase      <= ~win_phase;
                end else begin
                    win_tone_count <= win_tone_count + 16'd1;
                end

                if (win_count >= WIN_ON_FRAMES - 16'd1) begin
                    win_count      <= 16'd0;
                    win_tone_count <= 16'd0;
                    win_phase      <= 1'b0;
                    if (win_beep == 2'd2) begin
                        win_done <= 1'b1;
                    end else begin
                        win_gap  <= 1'b1;
                        win_beep <= win_beep + 2'd1;
                    end
                end else begin
                    win_count <= win_count + 16'd1;
                end
            end else begin
                if (win_count >= WIN_OFF_FRAMES - 16'd1) begin
                    win_count <= 16'd0;
                    win_gap   <= 1'b0;
                end else begin
                    win_count <= win_count + 16'd1;
                end
            end
        end

        // I2C service clock.
        if (!codec_ready) begin
            if (i2c_tick) i2c_div <= 9'd0;
            else          i2c_div <= i2c_div + 9'd1;
        end

        // Codec initialization over I2C.
        if (!codec_ready && i2c_tick) begin
            case (i2c_state)
                I2C_WAIT: begin
                    if (i2c_wait_cnt >= 16'd50000) begin
                        i2c_wait_cnt      <= 16'd0;
                        i2c_state         <= I2C_START;
                        i2c_scl_r         <= 1'b1;
                        i2c_sda_drive_low <= 1'b0;
                        cmd_index         <= 4'd0;
                        current_cmd       <= wm8731_cmd(4'd0);
                        current_byte      <= 8'h34; // WM8731 write address
                        byte_sel          <= 2'd0;
                        bit_sel           <= 3'd7;
                    end else begin
                        i2c_wait_cnt <= i2c_wait_cnt + 16'd1;
                    end
                end

                I2C_START: begin
                    i2c_scl_r         <= 1'b1;
                    i2c_sda_drive_low <= 1'b1;
                    i2c_state         <= I2C_BIT_LO;
                end

                I2C_BIT_LO: begin
                    i2c_scl_r         <= 1'b0;
                    i2c_sda_drive_low <= ~current_byte[bit_sel];
                    i2c_state         <= I2C_BIT_HI;
                end

                I2C_BIT_HI: begin
                    i2c_scl_r <= 1'b1;
                    if (bit_sel == 3'd0) begin
                        i2c_state <= I2C_ACK_LO;
                    end else begin
                        bit_sel   <= bit_sel - 3'd1;
                        i2c_state <= I2C_BIT_LO;
                    end
                end

                I2C_ACK_LO: begin
                    i2c_scl_r         <= 1'b0;
                    i2c_sda_drive_low <= 1'b0;
                    i2c_state         <= I2C_ACK_HI;
                end

                I2C_ACK_HI: begin
                    i2c_scl_r <= 1'b1;
                    if (byte_sel == 2'd0) begin
                        current_byte <= current_cmd[15:8];
                        byte_sel     <= 2'd1;
                        bit_sel      <= 3'd7;
                        i2c_state    <= I2C_BIT_LO;
                    end else if (byte_sel == 2'd1) begin
                        current_byte <= current_cmd[7:0];
                        byte_sel     <= 2'd2;
                        bit_sel      <= 3'd7;
                        i2c_state    <= I2C_BIT_LO;
                    end else begin
                        if (cmd_index == 4'd10) begin
                            i2c_state <= I2C_STOP;
                        end else begin
                            cmd_index    <= cmd_index + 4'd1;
                            current_cmd  <= wm8731_cmd(cmd_index + 4'd1);
                            current_byte <= 8'h34;
                            byte_sel     <= 2'd0;
                            bit_sel      <= 3'd7;
                            i2c_state    <= I2C_BIT_LO;
                        end
                    end
                end

                I2C_STOP: begin
                    i2c_scl_r         <= 1'b1;
                    i2c_sda_drive_low <= 1'b0;
                    codec_ready       <= 1'b1;
                    i2c_state         <= I2C_DONE;
                end

                default: begin
                    i2c_scl_r         <= 1'b1;
                    i2c_sda_drive_low <= 1'b0;
                    codec_ready       <= 1'b1;
                end
            endcase
        end

        // DAC serializer and PCM sample generation.
        if (bit_tick) begin
            if (bit_index == 5'd0) begin
                AUD_DACLRCK <= 1'b0;
                left_shift   <= current_sample[15:0];
                AUD_DACDAT   <= codec_ready ? current_sample[15] : 1'b0;
            end else if (bit_index < 5'd16) begin
                AUD_DACLRCK <= 1'b0;
                AUD_DACDAT   <= codec_ready ? left_shift[15] : 1'b0;
                left_shift   <= {left_shift[14:0], 1'b0};
            end else if (bit_index == 5'd16) begin
                AUD_DACLRCK <= 1'b1;
                right_shift  <= current_sample[15:0];
                AUD_DACDAT   <= codec_ready ? current_sample[15] : 1'b0;
            end else begin
                AUD_DACLRCK <= 1'b1;
                AUD_DACDAT   <= codec_ready ? right_shift[15] : 1'b0;
                right_shift  <= {right_shift[14:0], 1'b0};
            end

            if (bit_index == 5'd31) begin
                bit_index <= 5'd0;

                if (requested_mode != mode) begin
                    mode       <= requested_mode;
                    tone_count <= 16'd0;
                    tone_phase <= 1'b0;
                end

                case (requested_mode)
                    MODE_WIN: begin
                        if (!win_done && !win_gap) begin
                            if (win_tone_count >= HALF_880 - 16'd1) begin
                                win_tone_count <= 16'd0;
                                win_phase      <= ~win_phase;
                            end
                            current_sample <= win_phase ? AMP : -AMP;
                        end else begin
                            current_sample <= 16'sd0;
                        end
                    end

                    MODE_CRASH: begin
                        if (tone_count >= HALF_500 - 16'd1) begin
                            tone_count <= 16'd0;
                            tone_phase <= ~tone_phase;
                        end else begin
                            tone_count <= tone_count + 16'd1;
                        end
                        current_sample <= tone_phase ? AMP : -AMP;
                    end

                    MODE_COIN: begin
                        if (tone_count >= HALF_1000 - 16'd1) begin
                            tone_count <= 16'd0;
                            tone_phase <= ~tone_phase;
                        end else begin
                            tone_count <= tone_count + 16'd1;
                        end
                        current_sample <= tone_phase ? AMP : -AMP;
                    end

                    MODE_HONK: begin
                        if (tone_count >= HALF_440 - 16'd1) begin
                            tone_count <= 16'd0;
                            tone_phase <= ~tone_phase;
                        end else begin
                            tone_count <= tone_count + 16'd1;
                        end
                        current_sample <= tone_phase ? AMP : -AMP;
                    end

                    default: begin
                        current_sample <= 16'sd0;
                        tone_count     <= 16'd0;
                        tone_phase     <= 1'b0;
                    end
                endcase

                // Countdown the transient sounds once per frame.
                if (coin_frames_left != 16'd0)  coin_frames_left  <= coin_frames_left - 16'd1;
                if (crash_frames_left != 16'd0) crash_frames_left <= crash_frames_left - 16'd1;
            end else begin
                bit_index <= bit_index + 5'd1;
            end
        end
    end
end

endmodule
