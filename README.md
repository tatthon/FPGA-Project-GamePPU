# Vertical Platform Jumper

A Verilog game for 640 × 480 VGA at a 25.175 MHz pixel clock. Jump up a repeating course of grass platforms with Gamepad PMOD controller 1.

| Input | Action |
| --- | --- |
| D-pad Left or Right | Move four pixels per frame, including in midair |
| A | Jump from a platform. Release and press again for the next jump. |
| `rst_n = 0` | Return the player and camera to the starting platform |

The player can jump through platforms from below and lands when their feet cross a platform's top while descending. Platforms are 96 pixels wide and spaced 64 pixels apart vertically. The camera follows upward once the player's feet reach screen Y=240. The eight-row layout repeats every 512 world pixels, so the climb can continue across repeated layouts. Falling entirely below the visible screen returns the player to the start.

## Rendering and sprite RAM

- `platform_game.v` updates the player and camera at the start of VGA vertical blanking.
- `platform_map.v` supplies horizontal platform bounds for both drawing and collision checks.
- `platform_renderer.v` draws the left cap, four middle tiles, and right cap on each row.
- `sprite_ram.v` provides one synchronous read port and one synchronous write port. There are two instances, so the player and platform can each read a pixel in the same cycle. Both sprite layers and the VGA outputs are aligned to a two-clock pixel pipeline.

| Bank | Initial pixels | Stream address range |
| --- | --- | --- |
| Player | Twelve 8 × 8 tiles, also available in `data/player_tiles.mem` | 0–767 |
| Platform | Three 8 × 8 tiles in left, middle, right order, also available in `data/platform_tiles.mem` | 768–959 |

The memory files list pixels tile by tile in row-major order. Each pixel uses bit 6 for opacity and bits 5:0 for RGB222. The renderer doubles each source pixel in both directions. The VGA background behind transparent pixels is solid blue. Changing platform graphics leaves the 96 × 16 display bounds and platform collision geometry fixed.

### Loading pixels at runtime

Drive the inputs synchronously to `clk` and hold `ui_in[0:2]` low during ordinary gameplay.

1. With `rst_n` high, assert `ui_in[1]` for one rising edge. Set `ui_in[2]` to 0 for address 0 (player) or 1 for address 768 (platform).
2. Deassert `ui_in[1]`. Drive the next pixel on `uio_in[6:0]` and assert `ui_in[0]`. Each rising edge writes one pixel and advances the address. The address wraps from 959 to 0.
3. Deassert `ui_in[0]` to stop writing. Reset sets the write address to 0 and preserves RAM contents. The embedded graphics initialize the RAM when the FPGA configuration is loaded.

## Top module and pins

The top module is `tt_um_vga_example`. Gamepad PMOD latch, clock, and data are on `ui_in[4]`, `ui_in[5]`, and `ui_in[6]`. The bidirectional pins remain configured as inputs.

| Output | Signal | Output | Signal |
| --- | --- | --- | --- |
| `uo_out[0]` | R1 | `uo_out[4]` | R0 |
| `uo_out[1]` | G1 | `uo_out[5]` | G0 |
| `uo_out[2]` | B1 | `uo_out[6]` | B0 |
| `uo_out[3]` | VSync | `uo_out[7]` | HSync |

## Build and simulation

The default tiles are embedded in Verilog and can be loaded from any build directory. To load custom graphics from files instead, set the top parameters `PLAYER_INIT_FILE` and `PLATFORM_INIT_FILE` to paths that the simulator or FPGA build tool can resolve.

```bash
iverilog -g2012 -Wall -s tt_um_vga_example -o sim.vvp src/top_mario.v src/hsync_generator.v src/gamepad_pmod.v src/platform_game.v src/platform_map.v src/platform_renderer.v src/sprite_ram.v
vvp sim.vvp
```

The command checks compilation and memory initialization. A testbench must drive the clock, reset, and gamepad to simulate gameplay. Check the FPGA synthesis report for RAM inference and initialization. The Tiny Tapeout tile size in `info.yaml` is provisional.
