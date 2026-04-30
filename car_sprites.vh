// car_sprites.vh — 4 car sprite orientations (cardinal directions only)
//
// Car is 14 wide × 8 tall pixels (bounding box).
// Each sprite row is 14 bits wide (row-major, MSB = left column).
// Wider and shorter design for sleeker appearance.
// angle[2:0]: 0=Up, 1=Right, 2=Down, 3=Left
//
// Bit layout per row: bit[13] = leftmost pixel, bit[0] = rightmost pixel
// A '1' bit means draw the car pixel (yellow).

// New dimensions if rotated:
`define SPR_W 14
`define SPR_H 8

// ── angle 0 — Up (FLAT BODY + WIDE TOP) ───────────────────────────
// 14 bits per row (bit[13] = leftmost)

`define SPR_0_R00  14'b00111111111100
`define SPR_0_R01  14'b01111111111110
`define SPR_0_R02  14'b11111111111111
`define SPR_0_R03  14'b11111111111111
`define SPR_0_R04  14'b01111111111110
`define SPR_0_R05  14'b00111111111100
`define SPR_0_R06  14'b00011111111000
`define SPR_0_R07  14'b00001111110000