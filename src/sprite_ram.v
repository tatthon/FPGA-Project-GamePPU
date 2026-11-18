`timescale 1ns / 1ps

// One synchronous read port and one independent synchronous write port.
// Each word contains opacity in bit 6 and RGB222 in bits 5:0.
module sprite_ram #(
    parameter ADDR_WIDTH = 10,
    parameter PIXEL_COUNT = 768,
    parameter INIT_FILE = "",
    parameter [8*PIXEL_COUNT-1:0] INIT_PIXELS = 0
) (
    input  wire                  clk,
    input  wire [ADDR_WIDTH-1:0] read_addr,
    output reg  [6:0]            read_pixel,
    input  wire                  write_en,
    input  wire [ADDR_WIDTH-1:0] write_addr,
    input  wire [6:0]            write_pixel
);
    reg [6:0] pixels [0:PIXEL_COUNT-1];
    integer i;
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, pixels);
        end else begin
            // The most significant byte is pixel zero.
            for (i = 0; i < PIXEL_COUNT; i = i + 1)
                pixels[i] = INIT_PIXELS[8*(PIXEL_COUNT-1-i) +: 7];
        end
    end

    always @(posedge clk) begin
        if (write_en)
            pixels[write_addr] <= write_pixel;
        read_pixel <= pixels[read_addr];
    end
endmodule
