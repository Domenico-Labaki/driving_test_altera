// track_data.vh — Track geometry constants (VGA 640x480 pixel space)
// Edit ONLY this file to change the track layout.
//
// Coordinate system: px=[0,639], py=[0,479]
// Y increases downward (screen convention)
//
// All values derived from GEL372-DD.dxf via scale 22.448656 px/du, margin 20 px.

// ──────────────────────────────────────────────────────────
//  OUTER BOUNDARY (collision walls — keep car inside)
// ──────────────────────────────────────────────────────────
`define OUTER_LEFT    20
`define OUTER_RIGHT  620
`define OUTER_TOP     20
`define OUTER_BOTTOM 380

// Rounded corner parameters (top-right arc: (590,20)→(620,58))
`define TR_CORNER_X  590   // top-right corner x threshold
`define TR_CORNER_Y   58   // top-right corner y threshold
// Corner line: (px-590)*38 > (58-py)*30 → off track

// Rounded corner parameters (bottom-right arc: (620,350)→(581,380))
`define BR_CORNER_X  581   // bottom-right corner x threshold
`define BR_CORNER_Y  350   // bottom-right corner y threshold
// Corner line: (px-581)*30 < (py-350)*39 → off track

// ──────────────────────────────────────────────────────────
//  INNER BOUNDARY — V-NOTCH CHICANE (left side)
// ──────────────────────────────────────────────────────────
// Entity 1: inner_top_left_wall  y=91 from x=29 to x=186
`define INNER_TL_Y    91
`define INNER_TL_X1   29
`define INNER_TL_X2  186

// Entity 2: (186,91)→(83,178)   cross = -103*(py-91) - 87*(px-186)
`define E2_X1 186
`define E2_Y1  91
`define E2_X2  83
`define E2_Y2 178

// Entity 3: (83,178)→(117,219)  cross = 34*(py-178) - 41*(px-83)
`define E3_X1  83
`define E3_Y1 178
`define E3_X2 117
`define E3_Y2 219

// Entity 4: (117,219)→(274,91)  cross = 157*(py-219) + 128*(px-117)
`define E4_X1 117
`define E4_Y1 219
`define E4_X2 274
`define E4_Y2  91

// ──────────────────────────────────────────────────────────
//  INNER BOUNDARY — MAIN RIGHT ISLAND
// ──────────────────────────────────────────────────────────
// Top of main island: y≈90, x=274 to x=543  (entity 5)
`define ISLAND_TOP_Y   90
`define ISLAND_TOP_X1 274
`define ISLAND_TOP_X2 543

// Right island outer box (bounding): x=[274,543], y=[90,314]
`define ISLAND_BX1  274
`define ISLAND_BX2  543
`define ISLAND_BY1   90
`define ISLAND_BY2  314

// Right-side staircase (ON-TRACK cutout in the right island bounding box)
`define STEP_CUTOUT_X1  521
`define STEP_CUTOUT_X2  543
`define STEP_CUTOUT_Y1  103
`define STEP_CUTOUT_Y2  157

// Left wall of right island (x=318), y=[103,305]
`define ISLAND_LEFT_X  318
`define ISLAND_LEFT_Y1 103
`define ISLAND_LEFT_Y2 305

// Bottom of right island: y=305, x=[318,520]
`define ISLAND_BOT_Y  305
`define ISLAND_BOT_X1 318
`define ISLAND_BOT_X2 520

// Lower-right step: x=[520,543], y=[247,314]
`define STEP_LR_X1  520
`define STEP_LR_X2  543
`define STEP_LR_Y1  247
`define STEP_LR_Y2  314

// ──────────────────────────────────────────────────────────
//  INNER BOUNDARY — BOTTOM STEP STRUCTURE
// ──────────────────────────────────────────────────────────
// Inner bottom long horizontal: y=319, x=[237,507]
`define BOT_INNER_Y  319

// Bottom-left step: x=[103,237], y=[260,319]
`define BOT_LEFT_X1  103
`define BOT_LEFT_X2  237
`define BOT_LEFT_Y1  260
`define BOT_LEFT_Y2  319

// Bottom shelf: x=[103,237], y=[260,319]
`define SHELF_X1  103
`define SHELF_X2  237
`define SHELF_Y1  260
`define SHELF_Y2  319

// Bottom-right step extension: x=[507,543], y=[314,319]
`define BOT_EXT_X1  507
`define BOT_EXT_X2  543
`define BOT_EXT_Y1  314
`define BOT_EXT_Y2  319

// ──────────────────────────────────────────────────────────
//  START / FINISH BOX  (bottom-left rectangle)
// ──────────────────────────────────────────────────────────
// Acting as a starting bay/grid box on the left side
`define SF_X1  20
`define SF_X2  44
`define SF_Y1 320
`define SF_Y2 380

// ──────────────────────────────────────────────────────────
//  CONE POSITIONS (10 cones, driving test configuration)
// ──────────────────────────────────────────────────────────
// Format: {px[9:0], py[9:0]}  (20-bit packed)
`define NUM_CONES 10

// Top straightaway: Weaving / Slalom test
`define CONE_0  { 10'd200, 10'd40  }   
`define CONE_1  { 10'd250, 10'd70  }   
`define CONE_2  { 10'd300, 10'd40  }   
`define CONE_3  { 10'd350, 10'd70  }   

// Bottom straightaway: Parallel parking bay bounds
`define CONE_4  { 10'd300, 10'd340 }   // Front-left
`define CONE_5  { 10'd360, 10'd340 }   // Front-right
`define CONE_6  { 10'd300, 10'd370 }   // Back-left
`define CONE_7  { 10'd360, 10'd370 }   // Back-right

// Final approach: Narrow lane gate before finish
`define CONE_8  { 10'd30,  10'd250 }   
`define CONE_9  { 10'd80,  10'd250 }   

// ──────────────────────────────────────────────────────────
//  BUILDING SCENERY POSITIONS (Organized City Blocks / DMV)
// ──────────────────────────────────────────────────────────
// Format: {x1[9:0], y1[9:0], width[6:0], height[6:0]} (36-bit packed)
`define NUM_BUILDINGS 8

// Central DMV Testing Center complex (Right Island)
`define BLDG_0  { 10'd300, 10'd120, 7'd60, 7'd40 }  
`define BLDG_1  { 10'd380, 10'd120, 7'd60, 7'd40 }
`define BLDG_2  { 10'd460, 10'd120, 7'd60, 7'd40 }

// Row of terraced houses on the inner left block
`define BLDG_3  { 10'd150, 10'd260, 7'd30, 7'd30 }
`define BLDG_4  { 10'd200, 10'd260, 7'd30, 7'd30 }
`define BLDG_5  { 10'd250, 10'd260, 7'd30, 7'd30 }

// Spectator/Admin buildings near the slalom
`define BLDG_6  { 10'd200, 10'd110, 7'd40, 7'd30 }
`define BLDG_7  { 10'd260, 10'd110, 7'd40, 7'd30 }

// ──────────────────────────────────────────────────────────
//  CAR START POSITION AND HEADING
// ──────────────────────────────────────────────────────────
// Placed directly inside the starting bay, pointing out
`define CAR_START_X  10'd32   // center of start/finish box
`define CAR_START_Y  10'd360
`define CAR_START_ANGLE 3'd6  // heading UP (270 degrees)