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

// Row  0: __  __  __  DR  DR  DR  DR  DR  __  __  __
`define SPR_R00  22'b00_00_00_01_01_01_01_01_00_00_00

// Row  1: __  __  BK  BK  __  __  __  BK  BK  __  __
`define SPR_R01  22'b00_00_10_10_00_00_00_10_10_00_00

// Row  2: BK  BK  DR  DR  WH  WH  WH  DR  DR  BK  BK
`define SPR_R02  22'b10_10_01_01_11_11_11_01_01_10_10

// Row  3: BK  BK  DR  DR  WH  WH  WH  DR  DR  BK  BK
`define SPR_R03  22'b10_10_01_01_11_11_11_01_01_10_10

// Row  4: BK  BK  DR  BK  BK  BK  BK  BK  DR  BK  BK
`define SPR_R04  22'b10_10_01_10_10_10_10_10_01_10_10

// Row  5: __  DR  BK  BK  BK  BK  BK  BK  BK  DR  __
`define SPR_R05  22'b00_01_10_10_10_10_10_10_10_01_00

// Row  6: __  __  DR  DR  WH  WH  WH  DR  DR  __  __
`define SPR_R06  22'b00_00_01_01_11_11_11_01_01_00_00

// Row  7: __  __  BK  DR  BK  BK  BK  DR  BK  __  __
`define SPR_R07  22'b00_00_10_01_10_10_10_01_10_00_00

// Row  8: __  __  BK  DR  BK  BK  BK  DR  BK  __  __
`define SPR_R08  22'b00_00_10_01_10_10_10_01_10_00_00

// Row  9: __  __  DR  DR  WH  WH  WH  DR  DR  __  __
`define SPR_R09  22'b00_00_01_01_11_11_11_01_01_00_00

// Row 10: BK  BK  BK  DR  WH  WH  WH  DR  BK  BK  BK
`define SPR_R10  22'b10_10_10_01_11_11_11_01_10_10_10

// Row 11: BK  BK  BK  BK  WH  WH  WH  BK  BK  BK  BK
`define SPR_R11  22'b10_10_10_10_11_11_11_10_10_10_10

// Row 12: BK  BK  DR  BK  BK  BK  BK  BK  DR  BK  BK
`define SPR_R12  22'b10_10_01_10_10_10_10_10_01_10_10

// Row 13: __  __  DR  DR  WH  WH  WH  DR  DR  __  __
`define SPR_R13  22'b00_00_01_01_11_11_11_01_01_00_00
