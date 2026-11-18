`timescale 1ns / 1ps

// Vertical platform jumper with a gamepad-controlled character.
// Compatible with the original Tiny Tapeout VGA pin assignment.
module tt_um_vga_example #(
    parameter PLAYER_INIT_FILE = "",
    parameter PLATFORM_INIT_FILE = ""
) (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    wire hsync_raw, vsync_raw, display_on_raw;
    wire [9:0] pix_x, pix_y;

    hvsync_generator vga_sync_gen (
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync_raw),
        .vsync(vsync_raw),
        .display_on(display_on_raw),
        .hpos(pix_x),
        .vpos(pix_y)
    );

    wire pad_left, pad_right, pad_a;
    gamepad_pmod_single gamepad (
        .rst_n(rst_n),
        .clk(clk),
        .pmod_latch(ui_in[4]),
        .pmod_clk(ui_in[5]),
        .pmod_data(ui_in[6]),
        .b(), .y(), .select(), .start(), .up(), .down(),
        .left(pad_left),
        .right(pad_right),
        .a(pad_a), .x(), .l(), .r(), .is_present()
    );

    wire frame_tick = (pix_x == 10'd0) && (pix_y == 10'd480);
    localparam [9:0] PLAYER_WIDTH = 10'd32;
    localparam [9:0] PLAYER_HEIGHT = 10'd48;
    localparam [9:0] START_Y = 10'd448;
    localparam [11:0] FINISH_HEIGHT = 12'd1024;
    wire [9:0] player_x, player_feet_y;
    wire [11:0] camera_height;
    wire player_right, grounded, walk_frame, falling, won;
    platform_game #(
        .PLAYER_WIDTH(PLAYER_WIDTH),
        .START_Y(START_Y),
        .FINISH_HEIGHT(FINISH_HEIGHT)
    ) game (
        .clk(clk),
        .rst_n(rst_n),
        .frame_tick(frame_tick),
        .pad_left(pad_left),
        .pad_right(pad_right),
        .pad_a(pad_a),
        .player_x(player_x),
        .player_feet_y(player_feet_y),
        .camera_height(camera_height),
        .player_right(player_right),
        .grounded(grounded),
        .walk_frame(walk_frame),
        .falling(falling),
        .won(won)
    );

    // Stream pixels into either atlas using the spare input pins.
    // Addresses 0-767 are player pixels, 768-959 are platform pixels.
    localparam [9:0] PLATFORM_BASE = 10'd768;
    localparam [9:0] LAST_SPRITE_ADDR = 10'd959;
    reg [9:0] write_addr;
    wire sprite_write = rst_n && ui_in[0] && !ui_in[1];
    wire writing_platform = (write_addr >= PLATFORM_BASE);
    always @(posedge clk) begin
        if (!rst_n)
            write_addr <= 10'd0;
        else if (ui_in[1])
            write_addr <= ui_in[2] ? PLATFORM_BASE : 10'd0;
        else if (sprite_write)
            write_addr <= (write_addr == LAST_SPRITE_ADDR) ? 10'd0 : write_addr + 10'd1;
    end

    wire signed [13:0] height = $signed({2'b0, camera_height}) +
                                $signed({4'b0, START_Y}) -
                                $signed({4'b0, pix_y});
    wire [5:0] bg_color;
    platform_renderer #(
        .INIT_FILE(PLATFORM_INIT_FILE),
        .START_Y(START_Y),
        .FINISH_HEIGHT(FINISH_HEIGHT)
    ) background (
        .clk(clk),
        .rst_n(rst_n),
        .x(pix_x),
        .height(height),
        .won(won),
        .write_en(sprite_write && writing_platform),
        .write_addr(write_addr[7:0]),
        .write_pixel(uio_in[6:0]),
        .color(bg_color)
    );

    // Twelve 8x8 tiles, drawn at 2x scale. Bit 6 marks an opaque pixel.
    // The poses share the top four tiles and use separate bottom pairs.
    // Embedded defaults match data/player_tiles.mem, one literal per row.
    localparam [8*768-1:0] PLAYER_PIXELS = {
        64'h0000000000707070,
        64'h0000000000707070,
        64'h0000000000707070,
        64'h0000007070707070,
        64'h0000000079797979,
        64'h0000000079797979,
        64'h0000000079797979,
        64'h0000000079797979,

        64'h7070700000000000,
        64'h7070700000000000,
        64'h7070700000000000,
        64'h7070707070000000,
        64'h7979797900000000,
        64'h7940797900000000,
        64'h7940797900000000,
        64'h7979797900000000,

        64'h0000000040797979,
        64'h0000000070707070,
        64'h0000707070707070,
        64'h0000707070707070,
        64'h0000707070477947,
        64'h0000707070474747,
        64'h0000000070474747,
        64'h0000000000474747,

        64'h7979797900000000,
        64'h7070707000000000,
        64'h7070707070700000,
        64'h7070707070700000,
        64'h4779477070700000,
        64'h4747477070700000,
        64'h4747477000000000,
        64'h4747470000000000,

        64'h0000000000474747,
        64'h0000000000474747,
        64'h0000000047474700,
        64'h0000000047474700,
        64'h0000000047474700,
        64'h0000000047474700,
        64'h0000007070707000,
        64'h0000007070707000,

        64'h4747470000000000,
        64'h4747470000000000,
        64'h0047474700000000,
        64'h0047474700000000,
        64'h0047474700000000,
        64'h0047474700000000,
        64'h0070707070000000,
        64'h0070707070000000,

        64'h0000000000474747,
        64'h0000000000474747,
        64'h0000004747470000,
        64'h0000004747470000,
        64'h0000004747470000,
        64'h0000004747470000,
        64'h0000707070700000,
        64'h0000707070700000,

        64'h4747470000000000,
        64'h4747470000000000,
        64'h0000474747000000,
        64'h0000474747000000,
        64'h0000474747000000,
        64'h0000474747000000,
        64'h0000707070700000,
        64'h0000707070700000,

        64'h0000000000474747,
        64'h0000000000474747,
        64'h0000000047474700,
        64'h0000004747470000,
        64'h0000707070700000,
        64'h0000707070700000,
        64'h0000000000000000,
        64'h0000000000000000,

        64'h4747470000000000,
        64'h4747474700000000,
        64'h0047474747000000,
        64'h0000707070700000,
        64'h0000707070700000,
        64'h0000000000000000,
        64'h0000000000000000,
        64'h0000000000000000,

        64'h0000000000474747,
        64'h0000000000474747,
        64'h0000000047474700,
        64'h0000000047474700,
        64'h0000004747470000,
        64'h0000707070700000,
        64'h0000707070700000,
        64'h0000000000000000,

        64'h4747470000000000,
        64'h4747470000000000,
        64'h0047474700000000,
        64'h0000474747000000,
        64'h0000474747000000,
        64'h0000004747470000,
        64'h0000007070707000,
        64'h0000007070707000
    };

    wire [9:0] player_top = player_feet_y - PLAYER_HEIGHT;
    wire [9:0] sprite_dx = pix_x - player_x;
    wire [9:0] sprite_dy = pix_y - player_top;
    wire sprite_in_box = (sprite_dx < PLAYER_WIDTH) && (sprite_dy < PLAYER_HEIGHT);
    wire [3:0] sprite_x = player_right ? sprite_dx[4:1] : ~sprite_dx[4:1];
    wire [4:0] sprite_y = sprite_dy[5:1];
    wire [2:0] leg_tile_row = grounded ? {2'b01, walk_frame} : {2'b10, falling};
    wire [2:0] tile_row = sprite_y[4] ? leg_tile_row : {2'b00, sprite_y[3]};
    wire [9:0] sprite_address = {tile_row, sprite_x[3], sprite_y[2:0], sprite_x[2:0]};

    wire [6:0] sprite_pixel_d1;
    sprite_ram #(
        .INIT_FILE(PLAYER_INIT_FILE),
        .INIT_PIXELS(PLAYER_PIXELS)
    ) player_tiles (
        .clk(clk),
        .read_addr(sprite_address),
        .read_pixel(sprite_pixel_d1),
        .write_en(sprite_write && !writing_platform),
        .write_addr(write_addr),
        .write_pixel(uio_in[6:0])
    );

    reg sprite_in_box_d1;
    reg [6:0] sprite_pixel_d2;
    always @(posedge clk) begin
        if (!rst_n) begin
            sprite_in_box_d1 <= 1'b0;
            sprite_pixel_d2 <= 7'd0;
        end else begin
            sprite_in_box_d1 <= sprite_in_box;
            sprite_pixel_d2 <= sprite_in_box_d1 ? sprite_pixel_d1 : 7'd0;
        end
    end

    wire [5:0] final_color = sprite_pixel_d2[6] ? sprite_pixel_d2[5:0] : bg_color;

    // The tile pipeline delays RGB by 2 cycles compared with pixel coordinates.
    // VGA sync generator already registers sync once, so delay sync 1 more.
    reg active_d1, active_d2;
    reg hsync_d1, vsync_d1;
    always @(posedge clk) begin
        if (!rst_n) begin
            active_d1 <= 1'b0;
            active_d2 <= 1'b0;
            hsync_d1 <= 1'b1;
            vsync_d1 <= 1'b1;
        end else begin
            active_d1 <= display_on_raw;
            active_d2 <= active_d1;
            hsync_d1 <= hsync_raw;
            vsync_d1 <= vsync_raw;
        end
    end

    wire [1:0] R = active_d2 ? final_color[5:4] : 2'b00;
    wire [1:0] G = active_d2 ? final_color[3:2] : 2'b00;
    wire [1:0] B = active_d2 ? final_color[1:0] : 2'b00;

    assign uo_out = {hsync_d1, B[0], G[0], R[0],
                     vsync_d1, B[1], G[1], R[1]};
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;
    wire _unused_ok = &{ena, ui_in, uio_in};
endmodule
