// car_sprites_rot.vh — Rotated Car Sprite
// 14 wide × 11 tall pixels.
//
// 00 (T) = transparent | 01 (D) = dark red 
// 10 (B) = black       | 11 (W) = white

// car_sprites_rot.vh — Rotated Car Sprite (from reversed matrix)

`define SPR_W_ROT 14
`define SPR_H_ROT 11

// Row 0
`define SPR_ROT_R00  28'b00_10_10_10_00_00_00_00_00_10_10_10_00_00
// Row 1
`define SPR_ROT_R01  28'b00_10_10_10_00_00_00_00_01_10_10_10_00_00
// Row 2
`define SPR_ROT_R02  28'b01_01_10_10_01_10_10_01_10_01_01_01_01_00
// Row 3
`define SPR_ROT_R03  28'b01_10_10_01_01_01_01_01_01_10_10_01_01_01
// Row 4
`define SPR_ROT_R04  28'b11_10_11_11_11_10_10_11_10_10_11_11_11_01
// Row 5
`define SPR_ROT_R05  28'b11_10_11_11_11_10_10_11_10_10_11_11_11_01
// Row 6
`define SPR_ROT_R06  28'b11_10_11_11_11_10_10_11_10_10_11_11_11_01
// Row 7
`define SPR_ROT_R07  28'b01_10_10_01_01_01_01_01_01_10_10_01_01_01
// Row 8
`define SPR_ROT_R08  28'b01_01_10_10_01_10_10_01_10_01_01_01_01_00
// Row 9
`define SPR_ROT_R09  28'b00_10_10_10_00_00_00_00_01_10_10_10_00_00
// Row 10
`define SPR_ROT_R10  28'b00_10_10_10_00_00_00_00_00_10_10_10_00_00