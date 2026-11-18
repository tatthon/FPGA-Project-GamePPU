`timescale 1ns / 1ps

module platform_game #(
    parameter [9:0] PLAYER_WIDTH = 10'd32,
    parameter [9:0] START_Y = 10'd448,
    parameter [11:0] FINISH_HEIGHT = 12'd1024
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       frame_tick,
    input  wire       pad_left,
    input  wire       pad_right,
    input  wire       pad_a,
    output reg  [9:0] player_x,
    output reg  [9:0] player_feet_y,
    output reg [11:0] camera_height,
    output reg        player_right,
    output reg        grounded,
    output reg        walk_frame,
    output wire       falling,
    output reg        won
);
    localparam [9:0] WALK_SPEED = 10'd4;
    localparam [9:0] MAX_X = 10'd640 - PLAYER_WIDTH;
    localparam [9:0] CAMERA_LINE = 10'd240;
    localparam signed [5:0] JUMP_SPEED = 6'sd13;
    localparam signed [5:0] MAX_FALL_SPEED = 6'sd24;

    reg [1:0] walk_phase;
    reg pad_a_prev, jump_pending;
    reg signed [5:0] velocity_y;

    wire move_left = pad_left && !pad_right;
    wire move_right = pad_right && !pad_left;
    wire [9:0] next_x = move_left
                      ? ((player_x < WALK_SPEED) ? 10'd0 : player_x - WALK_SPEED)
                      : move_right
                      ? ((player_x > MAX_X - WALK_SPEED) ? MAX_X : player_x + WALK_SPEED)
                      : player_x;
    wire walking = (next_x != player_x);

    wire jump_pressed = pad_a && !pad_a_prev;
    wire start_jump = grounded && (jump_pending || jump_pressed);
    wire signed [5:0] vertical_step = start_jump ? -JUMP_SPEED
                                   : grounded ? 6'sd1 : velocity_y;
    wire signed [10:0] next_feet_y = $signed({1'b0, player_feet_y}) + vertical_step;
    assign falling = (velocity_y >= 6'sd0);

    // Find the first platform row at or below the current feet. The fall
    // speed is less than the 64-pixel row spacing, so only one can be crossed.
    wire [8:0] world_feet_y = player_feet_y[8:0] - camera_height[8:0];
    wire [5:0] row_gap = 6'd0 - world_feet_y[5:0];
    wire [8:0] landing_world_y = world_feet_y + {3'b0, row_gap};
    wire [10:0] landing_screen_y = {1'b0, player_feet_y} + {5'b0, row_gap};
    wire signed [13:0] landing_height = $signed({2'b0, camera_height}) +
                                        $signed({4'b0, START_Y}) -
                                        $signed({3'b0, landing_screen_y});
    wire signed [13:0] finish_height = $signed({2'b0, FINISH_HEIGHT});
    wire [9:0] platform_left, platform_right;
    platform_map landing_platform (
        .row(landing_world_y[8:6]),
        .left_edge(platform_left),
        .right_edge(platform_right)
    );

    wire lands = (vertical_step > 6'sd0) &&
                 (next_feet_y >= $signed(landing_screen_y)) &&
                 (landing_screen_y < 11'd480) &&
                 (landing_height >= 14'sd0) && (landing_height <= finish_height) &&
                 (next_x < platform_right) &&
                 (next_x + PLAYER_WIDTH > platform_left);
    wire respawn = (next_feet_y >= 11'sd528) && !lands;
    wire restart = won ? start_jump : respawn;
    wire camera_follows = (next_feet_y < $signed({1'b0, CAMERA_LINE}));
    wire [11:0] camera_step = {2'b0, CAMERA_LINE} - {1'b0, next_feet_y[10:0]};

    // Capture a short A press between frames while standing on a platform.
    always @(posedge clk) begin
        if (!rst_n) begin
            pad_a_prev <= 1'b0;
            jump_pending <= 1'b0;
        end else begin
            pad_a_prev <= pad_a;
            if (frame_tick)
                jump_pending <= 1'b0;
            else if (jump_pressed && grounded)
                jump_pending <= 1'b1;
        end
    end

    always @(posedge clk) begin
        if (!rst_n || (frame_tick && restart)) begin
            player_x <= 10'd288;
            player_feet_y <= START_Y;
            camera_height <= 12'd0;
            won <= 1'b0;
            player_right <= 1'b1;
            grounded <= 1'b1;
            velocity_y <= 6'sd0;
            walk_phase <= 2'd0;
            walk_frame <= 1'b0;
        end else if (frame_tick && !won) begin
            player_x <= next_x;
            if (walking)
                player_right <= move_right;

            if (walking && grounded && lands) begin
                walk_phase <= walk_phase + 2'd1;
                if (&walk_phase)
                    walk_frame <= ~walk_frame;
            end else begin
                walk_phase <= 2'd0;
                walk_frame <= 1'b0;
            end

            grounded <= lands;
            if (lands) begin
                player_feet_y <= landing_screen_y[9:0];
                velocity_y <= 6'sd0;
                won <= (landing_height == finish_height);
            end else begin
                if (camera_follows) begin
                    player_feet_y <= CAMERA_LINE;
                    camera_height <= camera_height + camera_step;
                end else begin
                    player_feet_y <= next_feet_y[9:0];
                end
                velocity_y <= (vertical_step < MAX_FALL_SPEED)
                            ? vertical_step + 6'sd1 : MAX_FALL_SPEED;
            end
        end
    end
endmodule
