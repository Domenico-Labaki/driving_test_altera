module driving_school_display (
    input wire pixel_clk,
    input wire [9:0] h_count, 
    input wire [9:0] v_count, 
    input wire [9:0] x_offset, 
    input wire [9:0] y_offset, 
    output reg [11:0] rgb      
);

    localparam WIDTH  = 300;
    localparam HEIGHT = 90;

    // Calculate relative position
    wire [9:0] rel_x = h_count - x_offset;
    wire [9:0] rel_y = v_count - y_offset;
    
    // Calculate ROM address: Address = (y * WIDTH) + x
    wire [14:0] rom_addr = (rel_y * WIDTH) + rel_x;
    wire [11:0] rom_data;

    // Inferring the ROM using M4K blocks
    // Quartus will use the .mif file to initialize these blocks
    reg [11:0] mem [0:26999] /* synthesis ram_init_file = "image_data.mif" */;

    always @(posedge pixel_clk) begin
        if (rel_x < WIDTH && rel_y < HEIGHT) begin
            rgb <= mem[rom_addr];
        end else begin
            // Transparent/Background color (Black for your road/track)
            rgb <= 12'h000; 
        end
    end

endmodule