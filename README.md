# Mojo workspace

### Human notes - Oct 

This is uploaded to GitHub just to record what the AI did for setting up a local Mojo v3 FPGA board. So far I successfully got the AI (Qwen 3.8 27b) to flash a LED pattern after some trial and error. This is an old board using proprietary software from Xilinx, a company that was purchased by AMD after my FPGA card was released. Old links don't work, but there are still AMD equivalent links.

This is the current (Oct 2026) link to download the Xilinx software used for building the bitstream: https://www.amd.com/en/support/downloads/adaptive-socs-and-fpgas/legacy-ise/v2012_4---14_7.html. Pick the 14.7 version, not 14.7 Windows 10 and Windows 11. There are 4 2 GB files to download and you need all 4. You need an AMD account to download.

I also needed a license file. To get that, I went to this link: https://account.amd.com/en/forms/license/license-form.html, filled in my information, and then picked ISE Webpack License from the options in the form. It emailed me the license file and I put in in the workspace directory.

I just purchased a Radeon 7900 XTX which has 24 GB VRAM, managed to get it to run on my ancient Asrock Z97 Pro3 motherboard from 2014, and I configured llama.cpp to use unsloth/Qwen3.8-27B-GGUF:Q4_K_M. I had context window issues but I managed to get 128k of context working after some tweaking. My llama command line: `llama serve -np 1 -n 4096 -fa on -c 131072 --cache-type-k q8_0 --cache-type-v q8_0 --batch-size 2048 --ubatch-size 256 --parallel 1 -lm none --host 0.0.0.0 -ngl 999`. I used pi as a harness running inside a docker container, and I started with pi-observational-memory but there were performance issues so I updated the Dockerfile to just install the latest from `@earendil-works/pi-coding-agent` and leave it at that.

The workspace directory here is largely AI created. The notes file at mojo-led-test-NOTES.md was written for recordkeeping in between restarts and it contains a lot of unnecessary detail and dead ends, but it seems interesting as a record. At the beginning of each session I just told the AI that there was a Mojo v3 FPGA and I wanted to create and upload a bitstream to flash LEDs for testing. I only stopped it after reading its thinking when I realized it was trying to workaround the lack of Xilinx and the lack of a license file, so I dropped both in the workspace directory and restarted the session. Each time it reinstalled the Xilinx ISE Webpack tool to /opt since the docker container only mounted the /workspace directory, so /opt was ephemeral. The AI figured out how to use `batchxsetup` so I did not need to click through anything to help with the installation process.

It successfully figured out flashing the bitstream on its own, or at least with example projects (the submodules in this directory) but not with my guidance. To verify that it wasn't just triggering a factory reset or uploading a .bit file it downloaded somewhere, I asked it to flash the LEDs in a pattern like 1 for 1 second, 10 for 1 second, 2 for 1 second, etc. It was successful at that, and also successful at modifying it to update the LED pattern every 100ms instead of every 1s.

# AI below

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
