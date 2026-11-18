`timescale 1ns / 1ps

module platform_renderer #(
    parameter INIT_FILE = "",
    parameter [9:0] START_Y = 10'd448,
    parameter [11:0] FINISH_HEIGHT = 12'd1024
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [9:0] x,
    input  wire signed [13:0] height,
    input  wire       won,
    input  wire       write_en,
    input  wire [7:0] write_addr,
    input  wire [6:0] write_pixel,
    output reg  [5:0] color
);
    localparam [5:0] SKY_COLOR = 6'h0b;
    localparam signed [13:0] COURSE_TOP = $signed({2'b0, FINISH_HEIGHT});
    localparam signed [13:0] COURSE_BOTTOM = -14'sd15;
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

    wire [8:0] world_y = START_Y[8:0] - height[8:0];
    wire [9:0] left_edge, right_edge;
    platform_map visible_platform (
        .row(world_y[8:6]),
        .left_edge(left_edge),
        .right_edge(right_edge)
    );

    wire in_platform = (world_y[5:4] == 2'd0) &&
                       (height >= COURSE_BOTTOM) && (height <= COURSE_TOP) &&
                       (x >= left_edge) && (x < right_edge);
    wire [9:0] dx = x - left_edge;
    wire is_finish = in_platform && (height > COURSE_TOP - 14'sd16);
    wire light_square = dx[3] ^ world_y[3];
    wire [5:0] finish_color = won ? (light_square ? 6'h3c : 6'h34)
                                  : (light_square ? 6'h3f : 6'h01);

    wire [5:0] atmosphere = (height >= 14'sd768) ? 6'h00 :
                            (height >= 14'sd640) ? 6'h01 :
                            (height >= 14'sd512) ? 6'h02 :
                            (height >= 14'sd384) ? 6'h06 :
                            (height >= 14'sd256) ? 6'h07 : SKY_COLOR;

    // Hash each 32x32 world cell to scatter stars that scroll with the course.
    wire [4:0] star_seed = {height[7:5], height[9:8]} ^
                          (x[9:5] + {x[6:5], x[9:7]});
    wire [4:0] star_x = 5'd6 + {1'b0, star_seed[4:1]};
    wire [4:0] star_y = 5'd6 + {1'b0, x[7:6], star_seed[3:2]};
    wire star = (height >= 14'sd512) && (star_seed[1:0] == 2'd0) &&
                (x[4:0] == star_x) && (height[4:0] == star_y);
    wire [5:0] sky = star ? (star_seed[4] ? 6'h3f : 6'h1b) : atmosphere;

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
    reg in_platform_d1, is_finish_d1;
    reg [5:0] sky_d1, finish_color_d1;
    always @(posedge clk) begin
        if (!rst_n) begin
            in_platform_d1 <= 1'b0;
            is_finish_d1 <= 1'b0;
            sky_d1 <= SKY_COLOR;
            finish_color_d1 <= 6'd0;
            color <= SKY_COLOR;
        end else begin
            in_platform_d1 <= in_platform;
            is_finish_d1 <= is_finish;
            sky_d1 <= sky;
            finish_color_d1 <= finish_color;
            color <= is_finish_d1 ? finish_color_d1 :
                     (in_platform_d1 && pixel[6]) ? pixel[5:0] : sky_d1;
        end
    end
endmodule
