// car_controller.v — Car physics: position, heading, speed.
//
// Fixed-point Q8.8 throughout (16-bit signed).
// Sprite rows exported as flat 112-bit bus: car_row_bus[k*14 +: 14] = row k.
//
// Heading updates in small degree steps internally.
// The renderer uses this heading to rotate the original sprite visually.
// Game-logic update occurs on each tick_60hz pulse (60 Hz, from vsync).

`include "car_sprites.vh"
`include "track_data.vh"

module car_controller (
    input  wire        clk50,
    input  wire        rst_n,
    input  wire        tick_60hz,
    input  wire [1:0]  game_state,
    input  wire        accel,
    input  wire        brake,
    input  wire        steer_left,
    input  wire        steer_right,
    input  wire        game_active,
    output reg  [9:0]  car_x,
    output reg  [9:0]  car_y,
    output reg  [2:0]  car_angle,
    output reg  [8:0]  heading_deg,
    output reg  [7:0]  speed_kph,
    // 8 sprite rows packed into one bus: row k = car_row_bus[k*14 +: 14]
    output reg  [307:0] car_row_bus
);

// ── Speed limits (Q8.8) ───────────────────────────────────────────────────
localparam signed [15:0] SPD_MAX   =  16'sh0100;  // +1.0 px/frame
localparam signed [15:0] SPD_MIN   = -16'sh0080;  // -0.5 px/frame (reverse)
localparam signed [15:0] SPD_ACCEL =  16'sh0005;  // 0.02 px/frame per tick
localparam signed [15:0] SPD_BRAKE =  16'sh0008;  // 0.03 px/frame per tick
localparam signed [15:0] SPD_DRAG  =  16'sh0003;  // 0.01 px/frame drag
localparam [8:0] TURN_STEP = 9'd5;

// ── 0..90 degree Q8.8 cosine table ──────────────────────────────────────
// Reused for sine via quadrant symmetry.
reg signed [15:0] trig_q8 [0:90];

initial begin
    trig_q8[0]  = 16'sd256;
    trig_q8[1]  = 16'sd256;
    trig_q8[2]  = 16'sd256;
    trig_q8[3]  = 16'sd256;
    trig_q8[4]  = 16'sd255;
    trig_q8[5]  = 16'sd255;
    trig_q8[6]  = 16'sd255;
    trig_q8[7]  = 16'sd254;
    trig_q8[8]  = 16'sd254;
    trig_q8[9]  = 16'sd253;
    trig_q8[10] = 16'sd252;
    trig_q8[11] = 16'sd251;
    trig_q8[12] = 16'sd250;
    trig_q8[13] = 16'sd249;
    trig_q8[14] = 16'sd248;
    trig_q8[15] = 16'sd247;
    trig_q8[16] = 16'sd246;
    trig_q8[17] = 16'sd245;
    trig_q8[18] = 16'sd243;
    trig_q8[19] = 16'sd242;
    trig_q8[20] = 16'sd241;
    trig_q8[21] = 16'sd239;
    trig_q8[22] = 16'sd237;
    trig_q8[23] = 16'sd236;
    trig_q8[24] = 16'sd234;
    trig_q8[25] = 16'sd232;
    trig_q8[26] = 16'sd230;
    trig_q8[27] = 16'sd228;
    trig_q8[28] = 16'sd226;
    trig_q8[29] = 16'sd224;
    trig_q8[30] = 16'sd222;
    trig_q8[31] = 16'sd219;
    trig_q8[32] = 16'sd217;
    trig_q8[33] = 16'sd215;
    trig_q8[34] = 16'sd212;
    trig_q8[35] = 16'sd210;
    trig_q8[36] = 16'sd207;
    trig_q8[37] = 16'sd204;
    trig_q8[38] = 16'sd202;
    trig_q8[39] = 16'sd199;
    trig_q8[40] = 16'sd196;
    trig_q8[41] = 16'sd193;
    trig_q8[42] = 16'sd190;
    trig_q8[43] = 16'sd187;
    trig_q8[44] = 16'sd184;
    trig_q8[45] = 16'sd181;
    trig_q8[46] = 16'sd178;
    trig_q8[47] = 16'sd175;
    trig_q8[48] = 16'sd171;
    trig_q8[49] = 16'sd168;
    trig_q8[50] = 16'sd165;
    trig_q8[51] = 16'sd161;
    trig_q8[52] = 16'sd158;
    trig_q8[53] = 16'sd154;
    trig_q8[54] = 16'sd150;
    trig_q8[55] = 16'sd147;
    trig_q8[56] = 16'sd143;
    trig_q8[57] = 16'sd139;
    trig_q8[58] = 16'sd136;
    trig_q8[59] = 16'sd132;
    trig_q8[60] = 16'sd128;
    trig_q8[61] = 16'sd124;
    trig_q8[62] = 16'sd120;
    trig_q8[63] = 16'sd116;
    trig_q8[64] = 16'sd112;
    trig_q8[65] = 16'sd108;
    trig_q8[66] = 16'sd104;
    trig_q8[67] = 16'sd100;
    trig_q8[68] = 16'sd96;
    trig_q8[69] = 16'sd92;
    trig_q8[70] = 16'sd88;
    trig_q8[71] = 16'sd83;
    trig_q8[72] = 16'sd79;
    trig_q8[73] = 16'sd75;
    trig_q8[74] = 16'sd71;
    trig_q8[75] = 16'sd66;
    trig_q8[76] = 16'sd62;
    trig_q8[77] = 16'sd58;
    trig_q8[78] = 16'sd53;
    trig_q8[79] = 16'sd49;
    trig_q8[80] = 16'sd44;
    trig_q8[81] = 16'sd40;
    trig_q8[82] = 16'sd36;
    trig_q8[83] = 16'sd31;
    trig_q8[84] = 16'sd27;
    trig_q8[85] = 16'sd22;
    trig_q8[86] = 16'sd18;
    trig_q8[87] = 16'sd13;
    trig_q8[88] = 16'sd9;
    trig_q8[89] = 16'sd4;
    trig_q8[90] = 16'sd0;
end

function signed [15:0] cos_deg_q8;
    input [8:0] ang;
    reg [8:0] rem;
    begin
        if (ang < 9'd90) begin
            rem = ang;
            cos_deg_q8 = trig_q8[rem];
        end else if (ang < 9'd180) begin
            rem = ang - 9'd90;
            cos_deg_q8 = -trig_q8[9'd90 - rem];
        end else if (ang < 9'd270) begin
            rem = ang - 9'd180;
            cos_deg_q8 = -trig_q8[rem];
        end else begin
            rem = ang - 9'd270;
            cos_deg_q8 = trig_q8[9'd90 - rem];
        end
    end
endfunction

function signed [15:0] sin_deg_q8;
    input [8:0] ang;
    reg [8:0] rem;
    begin
        if (ang < 9'd90) begin
            rem = ang;
            sin_deg_q8 = trig_q8[9'd90 - rem];
        end else if (ang < 9'd180) begin
            rem = ang - 9'd90;
            sin_deg_q8 = trig_q8[rem];
        end else if (ang < 9'd270) begin
            rem = ang - 9'd180;
            sin_deg_q8 = -trig_q8[9'd90 - rem];
        end else begin
            rem = ang - 9'd270;
            sin_deg_q8 = -trig_q8[rem];
        end
    end
endfunction

// ── Sprite ROM: 14 rows × 22 bits (2 bits per pixel, 11 pixels wide) ────
reg [21:0] sprite_rom [0:13];

initial begin
    sprite_rom[0]  = `SPR_R00;
    sprite_rom[1]  = `SPR_R01;
    sprite_rom[2]  = `SPR_R02;
    sprite_rom[3]  = `SPR_R03;
    sprite_rom[4]  = `SPR_R04;
    sprite_rom[5]  = `SPR_R05;
    sprite_rom[6]  = `SPR_R06;
    sprite_rom[7]  = `SPR_R07;
    sprite_rom[8]  = `SPR_R08;
    sprite_rom[9]  = `SPR_R09;
    sprite_rom[10] = `SPR_R10;
    sprite_rom[11] = `SPR_R11;
    sprite_rom[12] = `SPR_R12;
    sprite_rom[13] = `SPR_R13;
end

// ── Q8.8 position and speed registers ────────────────────────────────────
reg signed [17:0] pos_x_q8;
reg signed [17:0] pos_y_q8;
reg signed [15:0] speed_q8;

reg signed [33:0] dx_q16;
reg signed [33:0] dy_q16;
integer r;

// Helper: pack sprite rows into flat bus
task pack_sprite_bus;
    integer i;
    begin
        for (i = 0; i < 14; i = i + 1)
            car_row_bus[i*22 +: 22] <= sprite_rom[i];
    end
endtask

always @(posedge clk50) begin
    if (!rst_n) begin
        pos_x_q8  <= {2'b00, `CAR_START_X, 8'd0};
        pos_y_q8  <= {2'b00, `CAR_START_Y, 8'd0};
        speed_q8  <= 16'sh0000;
        heading_deg <= 9'd270;
        car_angle <= `CAR_START_ANGLE;
        car_x     <= `CAR_START_X;
        car_y     <= `CAR_START_Y;
        speed_kph <= 8'd0;
        pack_sprite_bus;
    end else if (game_state == 2'd0) begin
        pos_x_q8  <= {2'b00, `CAR_START_X, 8'd0};
        pos_y_q8  <= {2'b00, `CAR_START_Y, 8'd0};
        speed_q8  <= 16'sh0000;
        heading_deg <= 9'd270;
        car_angle <= `CAR_START_ANGLE;
        car_x     <= `CAR_START_X;
        car_y     <= `CAR_START_Y;
        speed_kph <= 8'd0;
        pack_sprite_bus;
    end else if (game_state == 2'd1) begin
        // Active driving: update physics at 60 Hz
        if (tick_60hz) begin
            // ── Steering ───────────────────────────────────────────────
            if (steer_left && !steer_right) begin
                if (heading_deg < TURN_STEP)
                    heading_deg <= heading_deg + 9'd360 - TURN_STEP;
                else
                    heading_deg <= heading_deg - TURN_STEP;
            end else if (steer_right && !steer_left) begin
                if (heading_deg >= 9'd360 - TURN_STEP)
                    heading_deg <= heading_deg + TURN_STEP - 9'd360;
                else
                    heading_deg <= heading_deg + TURN_STEP;
            end

            // Keep the legacy 8-way angle output for FSM compatibility.
            if (heading_deg < 9'd45)
                car_angle <= 3'd0;
            else if (heading_deg < 9'd90)
                car_angle <= 3'd1;
            else if (heading_deg < 9'd135)
                car_angle <= 3'd2;
            else if (heading_deg < 9'd180)
                car_angle <= 3'd3;
            else if (heading_deg < 9'd225)
                car_angle <= 3'd4;
            else if (heading_deg < 9'd270)
                car_angle <= 3'd5;
            else if (heading_deg < 9'd315)
                car_angle <= 3'd6;
            else
                car_angle <= 3'd7;

            // ── Speed ────────────────────────────────────────────────
            if (accel && !brake) begin
                if (speed_q8 < SPD_MAX) speed_q8 <= speed_q8 + SPD_ACCEL;
            end else if (brake && !accel) begin
                if (speed_q8 > SPD_MIN) speed_q8 <= speed_q8 - SPD_BRAKE;
            end else begin
                if      (speed_q8 >  SPD_DRAG) speed_q8 <= speed_q8 - SPD_DRAG;
                else if (speed_q8 < -SPD_DRAG) speed_q8 <= speed_q8 + SPD_DRAG;
                else                            speed_q8 <= 16'sh0000;
            end

            // ── Position: Q8.8 × Q8.8 = Q16.16 → take [23:8] for Q8.8 ─
            dx_q16 = $signed(speed_q8) * $signed(cos_deg_q8(heading_deg));
            dy_q16 = $signed(speed_q8) * $signed(sin_deg_q8(heading_deg));
            pos_x_q8 <= pos_x_q8 + {{2{dx_q16[33]}}, dx_q16[23:8]};
            pos_y_q8 <= pos_y_q8 + {{2{dy_q16[33]}}, dy_q16[23:8]};

            // Integer pixel coordinates
            car_x <= pos_x_q8[17:8];
            car_y <= pos_y_q8[17:8];

            // Speed in display units: include Q8.8 fraction (scale 25), cap at 99
            if (speed_q8[15])
                speed_kph <= 8'd0;  // negative speed shows 0 (keep current behavior)
            else begin
                if ((($unsigned(speed_q8) * 8'd25) >> 8) >= 8'd99)
                    speed_kph <= 8'd99;
                else
                    speed_kph <= (($unsigned(speed_q8) * 8'd25) >> 8);
            end

            // Sprite stays in the original orientation.
            pack_sprite_bus;
        end
    end else begin
        // FAIL or PASS: freeze all dynamic state (hold registers). Do nothing so
        // car remains exactly where it crashed or finished.
    end
end

endmodule