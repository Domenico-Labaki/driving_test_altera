// car_sprites.vh — Car sprite 11 wide × 14 tall pixels.
//
// Each row is 11 pixels. Each pixel is 2 bits:
//   00 = transparent
//   01 = dark red  (#880015)
//   10 = black     (#000000)
//   11 = white     (#FFFFFF, interior)
//
// Row encoding: 22 bits, MSB pair = leftmost pixel.
// car_row_bus: 14 rows × 22 bits = 308 bits total.
// Car points UP (north).

`define SPR_W 11
`define SPR_H 14

// Rotated sprite: CCW 90° mapped into same 11×14 bounding box
// (so the sprite visually points up without runtime heading offset).
// Row  0: all transparent
`define SPR_R00  22'b00_00_00_00_00_00_00_00_00_00_00

// Row  1: all transparent
`define SPR_R01  22'b00_00_00_00_00_00_00_00_00_00_00

// Row  2
`define SPR_R02  22'b10_10_10_00_00_00_00_01_10_10_10

// Row  3
`define SPR_R03  22'b01_10_10_01_10_10_01_10_01_01_10

// Row  4
`define SPR_R04  22'b10_10_01_01_01_01_01_10_10_01_10

// Row  5
`define SPR_R05  22'b10_11_11_11_10_10_11_10_10_11_11

// Row  6
`define SPR_R06  22'b10_11_11_11_10_10_11_10_10_11_11

// Row  7
`define SPR_R07  22'b10_11_11_11_10_10_11_10_10_11_11

// Row  8
`define SPR_R08  22'b10_10_01_01_01_01_01_10_10_01_01

// Row  9
`define SPR_R09  22'b01_10_10_01_10_10_01_10_01_01_01

// Row 10
`define SPR_R10  22'b10_10_10_00_00_00_00_01_10_10_10

// Row 11
`define SPR_R11  22'b10_10_10_00_00_00_00_00_01_01_10

// Row 12: all transparent
`define SPR_R12  22'b00_00_00_00_00_00_00_00_00_00_00

// Row 13: all transparent
`define SPR_R13  22'b00_00_00_00_00_00_00_00_00_00_00
