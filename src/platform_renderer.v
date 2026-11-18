`timescale 1ns / 1ps

module platform_renderer #(
    parameter INIT_FILE = ""
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [9:0] x,
    input  wire [8:0] world_y,
    input  wire       write_en,
    input  wire [7:0] write_addr,
    input  wire [6:0] write_pixel,
    output reg  [5:0] color
);
    localparam [5:0] SKY_COLOR = 6'h0b;
    // Embedded defaults match data/platform_tiles.mem, one literal per row.
    localparam [8*192-1:0] PLATFORM_PIXELS = {
        64'h446c6c6c6c6c6c6c,
        64'h445858586c58586c,
        64'h4458545458585858,
        64'h4454645454645464,
        64'h4451646474646464,
        64'h4451645164646551,
        64'h0044515151516451,
        64'h0000444444444444,

        64'h6c6c6c6c6c6c6c6c,
        64'h6c5858586c58586c,
        64'h5858545458585858,
        64'h5464645454645464,
        64'h6464647464646464,
        64'h6451646465516474,
        64'h5151516451515151,
        64'h4444444444444444,

        64'h6c6c6c6c6c6c6c44,
        64'h6c58586c58585844,
        64'h5858585854545844,
        64'h6454645454645444,
        64'h6464647464645144,
        64'h5165646451645144,
        64'h5164515151514400,
        64'h4444444444440000
    };

    wire [9:0] left_edge, right_edge;
    platform_map visible_platform (
        .row(world_y[8:6]),
        .left_edge(left_edge),
        .right_edge(right_edge)
    );

    wire in_platform = (world_y[5:4] == 2'd0) &&
                       (x >= left_edge) && (x < right_edge);
    wire [9:0] dx = x - left_edge;
    // Left cap, four repeats of the middle tile, then the right cap.
    wire [1:0] tile = (dx[6:4] == 3'd0) ? 2'd0 :
                      (dx[6:4] == 3'd5) ? 2'd2 : 2'd1;
    wire [7:0] read_addr = {tile, world_y[3:1], dx[3:1]};
    wire [6:0] pixel;
    sprite_ram #(
        .ADDR_WIDTH(8),
        .PIXEL_COUNT(192),
        .INIT_FILE(INIT_FILE),
        .INIT_PIXELS(PLATFORM_PIXELS)
    ) platform_tiles (
        .clk(clk),
        .read_addr(read_addr),
        .read_pixel(pixel),
        .write_en(write_en),
        .write_addr(write_addr),
        .write_pixel(write_pixel)
    );

    // RAM read is the first stage. Register the composited color next.
    reg in_platform_d1;
    always @(posedge clk) begin
        if (!rst_n) begin
            in_platform_d1 <= 1'b0;
            color <= SKY_COLOR;
        end else begin
            in_platform_d1 <= in_platform;
            color <= (in_platform_d1 && pixel[6]) ? pixel[5:0] : SKY_COLOR;
        end
    end
endmodule
