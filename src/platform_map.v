`timescale 1ns / 1ps

// Eight platform rows repeat every 512 world pixels.
module platform_map (
    input  wire [2:0] row,
    output reg  [9:0] left_edge,
    output wire [9:0] right_edge
);
    always @* begin
        case (row)
            3'd0, 3'd2: left_edge = 10'd192;
            3'd1:       left_edge = 10'd128;
            3'd3, 3'd7: left_edge = 10'd256;
            3'd4, 3'd6: left_edge = 10'd320;
            3'd5:       left_edge = 10'd384;
            default:    left_edge = 10'd256;
        endcase
    end

    // Six 16-pixel tiles. The right edge is exclusive.
    assign right_edge = left_edge + 10'd96;
endmodule
