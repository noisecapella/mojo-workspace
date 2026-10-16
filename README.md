# Mojo v3 LED test — build & flash workspace

Workspace for the **Mojo v3** board (ATmega32U4 + Xilinx **xc6slx9-tqg144-3**
Spartan-6 FPGA): LED test designs, simulation, ISE 14.7 bitstream builds, and
flashing through the on-board AVR loader.

**Start with [`mojo-led-test-NOTES.md`](mojo-led-test-NOTES.md)** — the main
working notes: verified build flow, ISE 14.7 install procedure (batch install,
license placement, multi-part archive gotcha), the complete AVR loader
protocol (including the little-endian size gotcha), and project history.

## Directory structure

| Path | What it is |
|---|---|
| `mojo-led-test-NOTES.md` | Main working notes: build/flash flow, ISE 14.7 install, protocol, history |
| `mojo-base-project/` | **Submodule — fork** of [embmicro/mojo-base-project](https://github.com/embmicro/mojo-base-project) — the LED designs: `src/led_test.v`, `src/led_test.ucf`, `src/led_fold.v` (branch `mojo-led-tests`) |
| `mojo-test/` | **Submodule — own repo** — `flash_led_test.py` (loader CLI) + iverilog sims and outputs in `build/` |
| `mojo-arduino/` | Submodule — AVR loader firmware (`mojo_loader.ino`), the protocol reference |
| `mojo-v3-loader/` | Submodule — upstream reference Python loader CLI |
| `mojo-myhdl/` | Submodule — reference design (MyHDL) |
| `osxMojo/` | Submodule — reference macOS flashing project |
| `mojo_hostmot2/` | Submodule — reference design (hostmot2) |
| `ColourRunner/` | Submodule — reference design (game) |
| `ceespu/` | Submodule — reference project (ESP) |
| `ntsc-mojo/` | Submodule — reference design (NTSC video) |
| `xilinx_ise/`, `Xilinx_ISE_DS_14.7_1015_1-*.tar` | *Excluded* — ISE 14.7 installer media (~10 GB); see notes |
| `Xilinx.lic` | *Excluded* — personal node-locked license file, **never committed** |

## Submodules

All ten project directories are git submodules — the repo stores only a URL
plus a pinned commit, not their code (no re-publishing, upstream licenses stay
with the upstream repos).

```sh
# clone everything at once:
git clone --recurse-submodules <this-repo-url>

# ...or after a plain clone:
git submodule update --init
```

`git submodule update --init` checks out exactly the pinned commits; add
`--remote` to follow each upstream's `master` instead.

## Forks / own repos

Two submodules point at my own repos rather than at the upstream projects:

- **`mojo-base-project/`** — fork of
  [embmicro/mojo-base-project](https://github.com/embmicro/mojo-base-project)
  at [noisecapella/mojo-base-project](https://github.com/noisecapella/mojo-base-project),
  pinned to branch `mojo-led-tests`, which adds the LED designs
  (`src/led_test.v`, `src/led_test.ucf`, `src/led_fold.v`). The local clone
  keeps `upstream` → embmicro for syncing.
- **`mojo-test/`** — my repo
  [noisecapella/mojo-test](https://github.com/noisecapella/mojo-test):
  flasher + sims.

## Designs

- **`led_test`** — `led[0]` blinks at ~1 Hz while a bit chases through
  `led[1..7]` at ~1.5 steps/s.
- **`led_fold`** — one LED on at a time, 100 ms per step, folding pattern
  1, 8, 2, 7, 3, 6, 4, 5 (outside-in), looping.

Both use the `led_test.ucf` pins (clk P56, rst_n P38,
led[0..7] = P134,133,132,131,127,126,124,123).

## Quick start: build & flash (Linux, ISE 14.7 at /opt/Xilinx)

```sh
source /opt/Xilinx/14.7/ISE_DS/settings64.sh
cd /tmp/ise_fold   # or any clean build dir
# xst -> ngdbuild -> map -> par -> bitgen — exact verified commands in the notes
python3 mojo-test/flash_led_test.py -p /dev/ttyACM0 -b /tmp/ise_fold/led_fold.bit
# expect:  'R' ack, 'O' ack, then 'D' + exit 0
```

Flashing takes ~15 s (340 KB over the 32U4's USB CDC link). See the notes for
the full protocol explanation and the byte-order bug history.

## AI assistance (provenance)

The ISE 14.7 install, bitstream builds, and the flasher byte-order fix in this
workspace were done with AI assistance: a pi coding agent driven by
`unsloth/Qwen3.8-27B-GGUF` (Q4_K_M) served by a local llama.cpp server, with
the agent's reasoning level set to `medium`.
