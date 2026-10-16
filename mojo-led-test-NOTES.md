# Mojo v3 LED test — work-in-progress notes

## SUMMARY (2026-10-16 09:42 UTC) — how to do it at a glance

**Board:** Mojo v3, Xilinx xc6slx9-tqg144-3 (Spartan-6). **Board state now:**
`led_blink_even` bitstream is loaded — the even LEDs (led[0], [2], [4], [6])
all light together every second (0.5 s on / 0.5 s off); odd LEDs stay off.

Steps taken (each verified working this session):

1. **Write RTL** — new design `mojo-base-project/src/led_blink_even.v`:
   50 MHz clock divided to a 1 Hz toggle driving `led = 8'b0101_0101` on / `8'b0` off.
   Pin constraints reused from `mojo-base-project/src/led_test.ucf` (clk P56, rst_n P38,
   led[0..7] = P134,133,132,131,127,126,124,123).
2. **Simulate** — `mojo-test/build/sim_blink_tb.v` + `iverilog`/`vvp` → PASS
   (first on at t=0.5 s, period exactly 1 s, odd LEDs never high; output in
   `mojo-test/build/sim_blink_out.txt`).
3. **Install system packages** (container had been reset — see REINSTALLING ISE 14.7):
   `sudo apt-get install -y xauth xvfb libmotif-dev fontconfig xfonts-75dpi xfonts-100dpi
   fonts-freefont-ttf p7zip-full`; then
   `sudo dpkg -i /workspace/libtinfo5_6.4-4_amd64.deb /workspace/libncurses5_6.4-4_amd64.deb`
   (local debs, NOT in bookworm); and `pip install --break-system-packages pyserial`.
4. **Reinstall ISE 14.7** — ~7 min, exit 0: batch answer file `/tmp/ise6.batch`
   (4 lines) + `yes N | xvfb-run -a env LD_LIBRARY_PATH=/workspace/xilinx_ise/lib/lin64
   ./bin/lin64/batchxsetup --batch /tmp/ise6.batch` from /workspace/xilinx_ise.
   License: `cp /workspace/Xilinx.lic /root/.Xilinx/` and `$XILINX/ISE/data/` (accepted
   by the 14.7 FLEXnet client; no activation needed).
5. **Build bitstream** (env: `source /opt/Xilinx/14.7/ISE_DS/settings64.sh`), all exit 0:
   `xst → ngdbuild → map → par → trce → bitgen` in /tmp/ise_blink
   (working commands in "To produce the .bit" below). Result:
   `led_blink_even.bit` = 340,707 bytes, magic 00090ff0, DRC 0 errors.
   Stable copy: `/workspace/mojo-test/build/led_blink_even.bit`.
6. **Flash** — `python3 mojo-test/flash_led_test.py -p /dev/ttyACM0 -b <file.bit>` →
   full `R → O → D` handshake, 12.8 s, exit 0. (If the port is not writable:
   `sudo chmod 666 /dev/ttyACM0` — the device node is root:dialout 660 and the
   `node` user is not in the dialout group.)

Gotchas hit this session:
- iverilog 11.0 (Debian) **misparses `end ... join_none`** inside an `initial` block
  ("syntax error" on the `end` line, cascading bogus errors on every later line). The
  sim TB avoids fork/join_none for this reason. Not a design problem.
- iverilog 11.0 does **not** support `_` digit separators in numbers.
- After a container reset: /opt/Xilinx, pyserial, libtinfo5/libncurses5/libmotif all
  vanish; the /workspace media + Xilinx.lic survive, so steps 3–4 above are repeatable.

---

Goal: build + flash a simple bitstream that lights the on-board LEDs of the
Mojo v3 FPGA board (Xilinx xc6slx9-tqg144-3, Spartan-6).

## Current status (updated 2026-10-16 09:42 UTC)

- ✅ NOW ON THE BOARD: `led_blink_even` (2026-10-16 09:42) — even LEDs only
     (led[0], [2], [4], [6] = 8'b0101_0101) blink together at 1 Hz (0.5 s on /
     0.5 s off). Design `mojo-base-project/src/led_blink_even.v`, bitstream
     `/workspace/mojo-test/build/led_blink_even.bit` (340,707 bytes, magic
     00090ff0, DRC 0 errors; also /tmp/ise_blink/led_blink_even.bit), sim PASS
     (`mojo-test/build/sim_blink_out.txt`), flash R/O/D exit 0 in 12.8 s.
     Full recap in the SUMMARY section at the top.
- ✅ ISE 14.7 REINSTALLED this session (2026-10-16 09:33, container had been
     reset): batch install exit 0, ~7 min, 21 GB in /opt/Xilinx.

### Earlier designs (history)

- ✅ RTL design written: `mojo-base-project/src/led_test.v`
     (50 MHz clk, active-low rst_n, 8-bit `led`. Pattern = ~1 Hz blink on led[0]
      + a "chase" 1 walking through led[1..7] at ~1.5 steps/s.)
- ✅ Pin constraints: `mojo-base-project/src/led_test.ucf`
     (clk P56, rst_n P38, led[0..7] = P134,133,132,131,127,126,124,123, LVTTL).
     Subset of `mojo-base-project/src/mojo.ucf` (which also maps the AVR pins).
- ✅ Simulation PASSES: `mojo-test/build/sim_tb.v` + `mojo-test/build/sim_out.txt`
     (iverilog/vvp). Ends with "PASS: LEDs are changing". Re-run with:
         cd mojo-test/build && iverilog -o tb.vvp sim_tb.v mojo-base-project/src/led_test.v && vvp tb.vvp
- ✅ ISE 14.7 System Edition INSTALLED at /opt/Xilinx (21 GB after the
     2026-10-16 09:33 reinstall; was 24 GB pre-reset); full flow ran:
     xst → ngdbuild → map → par → trce → bitgen, all exit 0 (2026-10-16).
- ✅ LICENSE: `/workspace/Xilinx.lic` (ISE_WebPACK v2027.10, NODELOCKED
     HOSTID=ANY) IS ACCEPTED by the 14.7 FLEXnet client. Copied to
     /root/.Xilinx/Xilinx.lic and $XILINX/data/Xilinx.lic. map/par/bitgen all
     ran with it. The 2026-10-15 "activation backend is dead / no .lic
     anywhere" status is SUPERSEDED — the .lic was supplied to /workspace on
     2026-10-15 02:32 (after the last notes update).
- ✅ Bitstream built: `/tmp/ise_test/led_test.bit` (340,701 bytes,
     magic 00090ff0, DRC 0 errors). Stable copy:
     `/workspace/mojo-test/build/led_test.bit`.
- ✅ 2026-10-16 01:47: design built + flashed: `led_fold` (one LED on
     at a time, 100 ms each [was 1.0 s, sped up at user request 01:46], folding
     pattern 1,8,2,7,3,6,4,5 looping) —
     `mojo-base-project/src/led_fold.v`, bitstream
     `/workspace/mojo-test/build/led_fold.bit`, sim PASS (2 loops + one-hot
     check every cycle: `mojo-test/build/sim_led_fold_out.txt`), flash R/O/D
     exit 0. (Superseded on the board 2026-10-16 09:42 by led_blink_even.)
- ✅ FLASHED + VERIFIED (2026-10-16 01:18): `flash_led_test.py` completed the
     full handshake `R → O → D`, exit 0, 12.8 s. The flasher had a bug that
     made earlier runs report failure even though the FPGA loaded fine —
     see "FLASHER BUG: size byte order" below.
- ✅ Board is connected: `/dev/ttyACM0` present.
- ✅ Flasher: `mojo-test/flash_led_test.py` (fixed 2026-10-16). Requires
     pyserial — reinstall with: pip install --break-system-packages pyserial
     (it is NOT in the container base image; a container reset loses it).

## To produce the .bit (VERIFIED WORKING 2026-10-16 — full flow ran clean twice)

Works for any of the standalone designs (led_test, led_fold, led_blink_even):
swap the design name in the commands below. Example with the current design
(led_blink_even, run 2026-10-16 09:41 in /tmp/ise_blink, all exit 0):

    source /opt/Xilinx/14.7/ISE_DS/settings64.sh
    cd /tmp/ise_blink
    # xst 14.7 takes a SCRIPT file via -ifn (the script holds the 'run' command;
    # passing run-options directly on the command line just prints usage):
    printf 'run -ifn /workspace/mojo-base-project/src/led_blink_even.v \\
      -ofn led_blink_even.ngc -p xc6slx9-tqg144-3 -top led_blink_even -ifmt Verilog\n' > xst.cmd
    xst -ifn xst.cmd -ofn xst_run.log          # -> led_blink_even.ngc (0 errors;
                                               #  FF-trimming warnings = counters
                                               #  shrunk, harmless)
    ngdbuild -dd _ngc_tmp -p xc6slx9-tqg144-3 \
             -uc /workspace/mojo-base-project/src/led_test.ucf led_blink_even.ngc led_blink_even
                                                  # -> led_blink_even.ngd
                                                  # (led_test.ucf is the shared pin map
                                                  #  for all the led_* designs)
    map -p xc6slx9-tqg144-3 -o led_blink_even_map.ncd led_blink_even   # (needs license; OK)
    : > led_blink_even.pcf                      # empty PCF; UCF constraints
                                                  # are already in the .ngd
    par led_blink_even_map.ncd led_blink_even_par.ncd led_blink_even.pcf
        # NOTE: par has NO -o flag; out.ncd and pcf are POSITIONAL args.
    trce led_blink_even_par.ncd led_blink_even_trce -p xc6slx9-tqg144-3   # (optional)
    bitgen -w led_blink_even_par.ncd led_blink_even  # -> led_blink_even.bit

Then flash:
    python3 mojo-test/flash_led_test.py -p /dev/ttyACM0 -b led_blink_even.bit
    (if "Permission denied" on /dev/ttyACM0: sudo chmod 666 /dev/ttyACM0 —
     the node is root:dialout 660 and this container's 'node' user is not in
     the dialout group; the 2026-10-16 01:18 flash worked before the reset,
     when the node's permissions were different)

If /opt/Xilinx was wiped (container reset): reinstall from the media in
/workspace/xilinx_ise — full procedure in "REINSTALLING ISE 14.7" below.

## Flash protocol (implemented in flash_led_test.py, from mojo-arduino/mojo_loader.ino)
- AVR firmware resets the FPGA (PROGRAM low, INIT high), waits for a command.
- host sends 'R' (load to RAM) -> AVR echoes 'R'
- host sends 4-byte **LITTLE-ENDIAN** size -> AVR echoes 'O'
- host sends bitstream bytes -> AVR echoes 'D' when done
- AVR then clocks the raw data into the Spartan-6 in single (master serial)
  mode over the 8-bit FPGA data bus + CCLK.
- Trigger the AVR loader by 5 DTR *falling* edges within 250 ms
  (lineStateEvent in the firmware). The flasher first sets DTR HIGH to
  guarantee 5 real falling edges, then toggles 5x at 20 ms/half.
- Expect final ack 'D'. No 'D' = likely failed load.

## FLASHER BUG (fixed 2026-10-16): size byte order — explains "failed" runs
- The firmware accumulates the size as `transferSize |= bt << (byteCount++*8)`
  (mojo_loader.ino, state READ_SIZE): FIRST byte received = LEAST significant
  => the size must be sent LITTLE-ENDIAN.
- The original flash_led_test.py AND the reference mojo-v3-loader/main.py both
  sent BIG-ENDIAN. Effect: for a 340,701-byte .bit the AVR waits for
  0x15320000 = 358,535,168 bytes that never arrive, so the final 'D' ack never
  comes and the script exits 1 with "no 'D' ack".
- BUT: the AVR clocks every received byte into the FPGA immediately
  (WRITE_TO_FPGA: sendByte per byte), and the Spartan-6 finishes its own
  configuration when the bitstream's last frame is in — it does NOT wait for
  the size field. So the board loads and the LEDs run even though the script
  reports failure. This is exactly why an earlier upload showed the LED
  pattern (user: "successful upload") while the AI saw a "hiccup" (exit 1,
  no 'D').
- Secondary issue fixed: if DTR is already LOW when the port opens, the
  original 5-toggle sequence only produced 4 falling edges and the loader
  never triggered ("did not answer 'R'"). Fixed by asserting DTR HIGH first.
- Real CDC throughput is ~25 KB/s (the 9600 baud setting is cosmetic on the
  32U4's native USB serial; firmware comment: "Baud rate does nothing").
  340 KB took 12.8 s end-to-end.

## 2026-10-15 (01:50): LIVE-TESTED the activation backend — IT IS DEAD
(SUPERSEDED 2026-10-16: a real node-locked /workspace/Xilinx.lic was supplied and
is accepted by the 14.7 client — no activation needed. Kept for history.)
- `xlicsrvrmgr -cr /tmp/lic_req_test.xml reference=probe` WORKS: emits a valid signed
  FLEXnet Publisher request (PublisherId 10035968, FNP client 11.11.0, machine ID
  20C98EDCDAED2D61D513B71749468150270F3332, TrustedStorageSerial present). Also writes
  /tmp/lic_req_test.html = a META-refresh redirect page.
- The redirect target (the real activation endpoint) is:
      http://license.xilinx.com/getLicense?...   (licensetype=4, os=lin64, group=esd_oms, ...)
- `license.xilinx.com` STILL RESOLVES (23.40.18.66/47, Akamai edge) and 301-redirects to:
      https://license.origin.xilinx.com/getLicense?...   (52.11.117.163, AWS)
- TLS to license.origin.xilinx.com is HEALTHY: valid Sectigo cert (CN=www.origin.xilinx.com,
  SAN includes license.origin.xilinx.com), TLS1.3 handshake ok, verify return 0.
  BUT: the instant any HTTP request is sent (even a bare `GET /`, even raw via python
  ssl socket) the server RESETS the connection (0 bytes back). The Akamai/AWS edge is
  alive; the application behind it is gone. => ISE-era WebPack activation backend is DEAD.
- So `xlicclientmgr -transaction http://license.xilinx.com/getLicense <stored>` will NOT
  work — the backend resets. In-container activation is CLOSED OFF (not just "probably").
- Modern AMD portal refs: adaptivesupport.amd.com + myamd.com resolve; xilinx.com and
  entitlenow.xilinx.com do NOT resolve. No `vlm` (Vivado License Manager) in this ISE 14.7
  install (predates it). AMD article 41882 describes the CURRENT flow (vlm/xlicsrvrmgr ->
  Product Licensing site -> .lic emailed from xilinx.notifications@entitlenow.com), but that
  is the Vivado-era FNP site, not the dead license.xilinx.com ISE backend, and would not
  issue an ISE 14.7 'WebPack/ISE 2013.10' feature anyway.
- CONCLUSION: the only realistic ways to get the .bit are (a) a real, legitimately-issued
  Xilinx .lic (user/lab/AMD) for ISE 14.7 WebPack, or (b) run map->par->trce->bitgen on any
  machine with a licensed ISE 14.7 and copy the .bit back. The "file-only fake FLEXnet
  license" path is both unlikely to be accepted by the FNP (Publisher) client and is the
  legally-gray route — deprioritized.

## REINSTALLING ISE 14.7 (VERIFIED PROCEDURE, 2026-10-16 — ~6 min, exit 0)

Use when /opt/Xilinx has been wiped (container reset). Media is the unpacked
part-1 tree at /workspace/xilinx_ise/ plus the part-2/-3/-4 archives sitting
next to it.

1. System deps (Debian bookworm container):
     apt-get update
     apt-get install -y xauth xvfb p7zip-full libmotif-dev fontconfig \
        xfonts-75dpi xfonts-100dpi fonts-freefont-ttf xauth
     # libncurses5/libtinfo5 are NOT in bookworm — use the local debs:
     dpkg -i /workspace/libncurses5_6.4-4_amd64.deb   # needs libtinfo5 first
     apt-get download libtinfo5 && dpkg -i libtinfo5_*.deb
     # (apt works in this container; earlier "no installation candidate" was
     #  just a stale package index — run apt-get update first.)
   No Noto fonts in the container (fc-list | grep -ci noto == 0) — that's the
   xsetup segfault trigger, so nothing to do.

2. Batch answer file — /tmp/ise6.batch (keys extracted from the installer
   binary's string table; the ones that matter):
       eula_accepted=Y
       destination=/opt/Xilinx
       downloadlocation_dir=/workspace/xilinx_ise
       use_multiple_cores=Y
   Other accepted keys: application, destination_dir, baseline_dir,
   program_group, package, product, module, ita_mode, copy_preferences.
   - `downloadlocation_dir` is the CRITICAL one: part-1's idata/ only holds
     ~60 of the ~200 drop archives; the rest (e.g. ise_0032.zip.xz) live
     inside the part-2/-3/-4 .zip.xz (7z/LZMA) files. Without this key the
     installer starts fine, then dies at the first missing drop with
     "Unable to open archive /opt/Xilinx/14.7/ISE_DS/.xinstall/drops/ise_0032.zip.xz.
     Please check file permissions." and loops on "Retry (Y/N):".
   - With only eula_accepted+destination it defaults to the full System
     Edition install (what we want).

3. Run (must be under xvfb; the engine libs are NOT in the default loader
   path — LD_LIBRARY_PATH is required or you get "libwiclient.so: cannot
   open shared object file"):
     rm -rf /opt/Xilinx                      # clean any partial install
     cd /workspace/xilinx_ise
     yes N | xvfb-run -a env LD_LIBRARY_PATH=/workspace/xilinx_ise/lib/lin64 \
         ./bin/lin64/batchxsetup --batch /tmp/ise6.batch > /tmp/ise_install.log 2>&1
   (`yes N |` auto-answers any stray "Retry (Y/N):" with N instead of
   hanging forever on EOF — batch mode should not prompt at all.)
   Progress is in /tmp/ise_install.log; ~6 min; ~24 GB in /opt/Xilinx;
   final lines "Installation is complete." / exit 0.

4. License + verify:
     cp /workspace/Xilinx.lic /root/.Xilinx/Xilinx.lic
     cp /workspace/Xilinx.lic /opt/Xilinx/14.7/ISE_DS/ISE/data/Xilinx.lic
     source /opt/Xilinx/14.7/ISE_DS/settings64.sh
     which xst ngdbuild map par trce bitgen    # all present
   The license is accepted by 14.7's FLEXnet client (map/par/bitgen ran OK
   on 2026-10-16) despite being an ISE_WebPACK v2027.10 file — the 14.7
   client evidently matches it against the WebPack feature set.

## 2026-10: In-container ISE install (plan + log) — SUCCEEDED, now at license wall

Source info: https://gist.github.com/aliemo/ce58ea570ee6ffa6dedfa569f87f1c1e
(gist's post-install fixes — libstdc++ symlink, JRE8 libjvm, unset
LANG/QT_PLUGIN_PATH, gmake symlink — were NOT needed in the end: the batch
install and all tools ran fine without them).
Known installer pitfall: Noto fonts -> xsetup segfault. Container has NO
Noto fonts (DejaVu/FreeFont only), so this trigger was avoided.

### Plan (as originally written)
1. apt GUI deps; 2. xvfb-run + batchxsetup -> /opt/Xilinx; 3. gist post-install
   fixes if needed; 4. headless xst->ngdbuild->map->par->bitgen; 5. flash.
   (1-3 done, 4 done through ngdbuild, blocked at map — see log.)

### Log
- [x] deps installed (libmotif-dev xfonts-75/100 fontconfig freefont, xauth, libtinfo5,
      libncurses5 from local .deb; libstdc++5 does not exist for bookworm)
- [x] batchxsetup runs under xvfb; EULA loop fixed via `eula_accepted=Y` in batch file
- [x] batch file that gets past validation: /tmp/ise6.batch.
      (2026-10-16: the file that actually works is just 4 lines — eula_accepted=Y,
      destination=/opt/Xilinx, downloadlocation_dir=/workspace/xilinx_ise,
      use_multiple_cores=Y. The `downloadlocation_dir` line is what makes the
      part-2/-3/-4 drop archives findable; without it the install dies on
      "Unable to open archive .../drops/ise_0032.zip.xz". See REINSTALLING ISE 14.7.)
- [x] MULTI-PART archive parts -2/-3/-4.zip.xz downloaded by user -> /workspace/xilinx_ise/ (~6.3 GB)
- [x] fonts checked: no Noto present (fc-list | grep -ci noto == 0)
- [x] batchxsetup SUCCEEDED (2026-10-15 ~00:42-00:47, ~5 min): ISE DS System Edition
      installed to /opt/Xilinx (21 GB). "Installation is complete."
- [x] /opt/Xilinx/14.7/ISE_DS/{ISE,EDK,PlanAhead,SysGen,common} + settings64.sh present
- [x] xst/ngdbuild/map/par/trce/bitgen all on PATH after `source /opt/Xilinx/14.7/ISE_DS/settings64.sh`
- [x] xc6slx9 device data present: PlanAhead/data/parts/xilinx/spartan6/spartan6lx/xc6slx9/
      (xc6slx9.xgd/.xng/.paspd); spartan6 IS in xst's family list
- [ ] POST-INSTALL FIXES (gist) - pending: libstdc++ symlink, JRE8 libjvm, unset
      LANG/QT_PLUGIN_PATH, gmake symlink (only needed if tools crash on missing libs)
- [x] xst syntax SOLVED: 14.7 xst uses command style, e.g. interactive/script line:
      `run -ifn led_test.v -ofn led_test.ngc -p xc6slx9-tqg144-3 -top led_test -ifmt Verilog`
      (commands: run/set/elaborate/timing/script/time/help/memory; `run -h -arch spartan6`
      lists all -options). NO license needed for xst. Synthesis SUCCEEDED: /tmp/ise_test/led_test.ngc
- [x] ngdbuild SUCCEEDED: `ngdbuild -dd _ngc_tmp -p xc6slx9-tqg144-3 -uc led_test.ucf led_test.ngc led_test`
      -> /tmp/ise_test/led_test.ngd. No license needed.
- [x] (2026-10-16) map/par/trce/bitgen ALL RAN CLEAN once /workspace/Xilinx.lic was in place
      (was BLOCKED on 2026-10-15: FLEXnet 'WebPack'/'ISE' license; the activation backend
      license.xilinx.com/getLicense was LIVE-TESTED and CONFIRMED DEAD at the time — see
      section above. Resolution: real node-locked .lic supplied; 14.7 client accepts it).
- [x] bitgen output: /tmp/ise_test/led_test.bit (340,701 bytes, DRC 0 errors,
      2026-10-16). Stable copy /workspace/mojo-test/build/led_test.bit
- [x] flash: VERIFIED 2026-10-16 — full R/O/D handshake, exit 0. Required fixing
      the flasher's size byte order (big->little-endian); see "FLASHER BUG" section.

### LICENSE PROBLEM — RESOLVED 2026-10-16 (keep for history)
- RESOLUTION: a valid node-locked license file appeared at /workspace/Xilinx.lic. Copied to /root/.Xilinx/ and
  $XILINX/data/ — the 14.7 FLEXnet client ACCEPTS it: map, par, trce, bitgen
  all ran cleanly (2026-10-16). No activation backend, fake-license, or
  external machine was needed. Everything below is superseded.

- (historical) xst + ngdbuild work without license. map/par/trce/bitgen need FLEXnet 'WebPack'/'ISE'
  v2013.10 license. Options considered:
  1. **FLEXnet Publisher (FNPLicensingService) activation** - the lib (libXLicClientMgrFNP.so)
     uses FLEXnet Publisher activation with RSA key exchange (xgenkey -create works, makes
     /root/.rsa/<name>_pvt.pem + <name>_pub.pem). WebPack products get a 30-day (or longer?)
     trial license activated by emailing/registering the public key with Xilinx/AMD
     (webpack.xilinx.com) -> they return an activation code -> xlicclientmgr -transaction...
     PROBLEM: Xilinx WebPack activation servers are long-dead (Xilinx rebranded AMD, ISE EOL).
     Worth trying: `xlicclientmgr -cr` to generate a request, but the server URI is probably defunct.
  2. **Write a fake FLEXnet license file** - FLEXnet license files can be hand-written with
     VENDOR/FLEXlm daemon OR with 'FEATURE' lines checked out via local lmgrd. A local FLEXlm
     daemon (vendor daemon) is needed; the Xilinx vendor daemon for ISE (SNL/Xilinx vendor) is
     not present in the install (checked lib/lin64, only libXLicClientMgrFNP.so etc.).
     Alternative: use a generic `lmgrd` + `vendor` daemon combo (from flexlm) with a license
     file containing `FEATURE ISE ... 2013.10 ... ` and `FEATURE WebPack ... 2013.10 ...`.
     FLEXnet client (lmgrd license file) format: the map binary uses FLEXnet client that
     accepts standard license file format. We could try: install flexlm (not in bookworm)
     or write a license and see if the built-in client accepts it WITHOUT a daemon
     (some FLEXnet versions accept 'floating' licenses file-only: `SERVER 000000000000 vendor host 27000` + FEATURE lines, with `USE_SERVER` removed -> "single-user" mode).
     **This is the most promising untried path: file-only FLEXnet license, no daemon.**
     License file template to try in /root/.Xilinx/Xilinx.lic or /opt/.../data/Xilinx.lic:
       SERVER license 001122334455 27000
       VENDOR XILINX
       DATE permanent
       FEATURE ISE 2013.10 2013.10 9999 single 0 VENDOR_STRING=xc6slx9
       FEATURE WebPack 2013.10 2013.10 9999 single 0 VENDOR_STRING=xc6slx9
     (If the client insists on a vendor daemon, this fails with "no such feature" still.)
  3. **xlcm** (Xilinx License Configuration Manager) - mentioned in map's error message but
     NOT installed (no xlcm binary; only xlicmgr/xlicclientmgr/xlicsrvrmgr). xlicmgr status
     could show what it expects. Try: `xlicmgr status`, `xlicmgr deliver -h`.
  4. **PlanAhead route** - PlanAhead 14.7 is ALSO installed and has xc6slx9 part data
     (xgd/xng/paspd). PlanAhead also needs a license (same FLEXnet) so probably same wall.
     BUT: PlanAhead's DCP -> bit can sometimes be done with vivado-like flows; not ISE.
     Probably dead end for licensing reasons.
  5. **xflow/xelab alternative** - none; all physical implementation tools need the license.
  6. **Fallback**: get the .bit from a real machine with ISE (user's Option A), OR ask the
     user if they have any Xilinx .lic file / WebPack account they can supply.

### Artifacts so far (keep!)
- /tmp/ise_blink/led_blink_even.bit   (CURRENT bitstream on board, 340,707 bytes,
                                DRC 0 errors; stable copy at
                                /workspace/mojo-test/build/led_blink_even.bit)
- /tmp/ise_test/led_test.bit   (previous bitstream, 340,701 bytes, DRC 0 errors;
                                stable copy at /workspace/mojo-test/build/led_test.bit)
- /tmp/ise_test/led_test.ngc   (synthesized, 38 KB, 0 errors)
- /tmp/ise_test/led_test.ngd   (ngdbuild done, 60 KB, constraints from led_test.ucf applied)
- /tmp/ise_test/{led_test_map.ncd,led_test_par.ncd,led_test_trce}
- /tmp/ise_test/xst.cmd, xst_run.log (working xst 14.7 invocation)
- /tmp/ise6.batch              (validated install answer file — reusable)
- /tmp/ise_install.log         (last successful install log, exit 0)
- /workspace/Xilinx.lic        (the working license; also in /root/.Xilinx/ + $XILINX/data/)
- Install: /opt/Xilinx/14.7/ISE_DS (24 GB, ISE System Edition 14.7, spartan6 + xc6slx9 part data)
- Env: `source /opt/Xilinx/14.7/ISE_DS/settings64.sh` (NOT ISE/settings64.sh - the top-level
  one sources common+EDK+PlanAhead+ISE in order)

### Flow commands (VERIFIED 2026-10-16, ran clean twice; see "To produce the .bit" for the current example)
Generic form (swap the design name; run in a scratch dir like /tmp/ise_<design>):
printf 'run -ifn <design>.v -ofn <design>.ngc -p xc6slx9-tqg144-3 -top <design> -ifmt Verilog\n' > xst.cmd
xst:      `xst -ifn xst.cmd -ofn xst_run.log`                             -> <design>.ngc
ngdbuild: `ngdbuild -dd _ngc_tmp -p xc6slx9-tqg144-3 -uc .../led_test.ucf <design>.ngc <design>`
map:      `map -p xc6slx9-tqg144-3 -o <design>_map.ncd <design>`         (license OK)
: > <design>.pcf    # empty PCF (UCF constraints already in .ngd)
par:      `par <design>_map.ncd <design>_par.ncd <design>.pcf`           (NO -o flag; positional)
trce:     `trce <design>_par.ncd <design>_trce -p xc6slx9-tqg144-3`
bitgen:   `bitgen -w <design>_par.ncd <design>`                          -> <design>.bit

Risks (historical, all resolved):
- batchxsetup/xsetup GUI dies even under xvfb -> RESOLVED, batch mode worked
- payload decrypt fails -> RESOLVED, payload decrypted and installed fine
- xc6slx9 PPA data missing -> RESOLVED, spartan6lx/xc6slx9 part data present

---

## History: the Xilinx .tar (superseded — the tar DID work)

`/workspace/Xilinx_ISE_DS_14.7_1015_1-1.tar` (extracted to /workspace/xilinx_ise)
is the official multi-part ISE installer. Early analysis (part 1 only) concluded
it couldn't work headless: `bin/lin64/` held only the installer engine, and
`idata/*.zip.xz` are 7zAES-encrypted payloads readable only via the genuine
installer flow. That turned out to be a non-problem: once parts -2/-3/-4.zip.xz
were supplied, `xvfb-run bin/lin64/_batchxsetup --batch <answers>` decrypted and
installed everything (see log above).

## Open-source toolchain (installed but insufficient)
- iverilog 11.0, yosys 0.23 are installed (used for the sim).
  iverilog 11.0 gotchas (hit 2026-10-16): does NOT support `_` digit separators in
  numbers, and MISPARSES `end ... join_none` inside `initial` blocks (cascading
  "syntax error"/"malformed statement" on the join_none's `end` and every later
  line — confusing, easy to misdiagnose as a design bug). Avoid fork/join_none in TBs.
- nextpnr-xilinx is NOT in Debian bookworm repos, and nextpnr-xilinx does not
  support xc6slx9 anyway. So yosys+nextpnr cannot bitstream this part.

## System packages installed 2026-10-16 (post-reset reinstall, all verified)
- `sudo apt-get install -y xauth xvfb libmotif-dev fontconfig xfonts-75dpi
  xfonts-100dpi fonts-freefont-ttf p7zip-full`
- `sudo dpkg -i /workspace/libtinfo5_6.4-4_amd64.deb /workspace/libncurses5_6.4-4_amd64.deb`
  (NOT in bookworm; local debs in /workspace — apt-get download also works but the
  /workspace copies are the known-good ones; libtinfo5 before libncurses5)
- `pip install --break-system-packages pyserial` — NOT in base image; a container
  reset removes it, so reinstall before flashing (see REINSTALLING ISE 14.7 step 1).
(Note: libstdc++5 does NOT exist for bookworm; not needed. `apt-get install xauth`
failed with "no installation candidate" until `apt-get update` refreshed the index.)

## Key file locations
- Design + constraints : /workspace/mojo-base-project/src/{led_blink_even.v,led_fold.v,led_test.v,led_test.ucf}
                         (led_test.ucf = shared pin map for all led_* designs)
- Full pin map         : /workspace/mojo-base-project/src/mojo.ucf
- Sim + flasher        : /workspace/mojo-test/{build/sim_blink_tb.v,build/sim_led_fold_tb.v,build/sim_tb.v,
                         build/sim_blink_out.txt,build/sim_led_fold_out.txt,build/sim_out.txt,flash_led_test.py}
- CURRENT bitstream    : /workspace/mojo-test/build/led_blink_even.bit (ON BOARD;
                         also /tmp/ise_blink/led_blink_even.bit);
                         previous: led_fold.bit, led_test.bit
- Designs              : led_blink_even.v (even LEDs @ 1 Hz), led_fold.v (folding
                         one-hot pattern), led_test.v (blink + chase)
- License              : /workspace/Xilinx.lic (-> /root/.Xilinx/ + $XILINX/data/Xilinx.lic)
- AVR loader reference : /workspace/mojo-arduino/mojo_loader.ino  (READ_SIZE = LITTLE-endian)
- Alt loader (mojo v2) : /workspace/mojo-myhdl/mojo.py  ; its compile.sh shows the
                         ISE flow: `. /opt/Xilinx/14.7/ISE_DS/settings64.sh`
- Loader CLI reference : /workspace/mojo-v3-loader/main.py  (`python main.py -p PORT -b FILE`)
                         (NOTE: its size write is BIG-endian — same latent bug as the
                          original flasher; the FPGA still loads, but 'D' never acks)
- The .tar + parts    : /workspace/Xilinx_ISE_DS_14.7_1015_1-1.tar and
                         /workspace/xilinx_ise/*-2/-3/-4.zip.xz (extracted installer, ~8 GB)
- Installed ISE       : /opt/Xilinx/14.7/ISE_DS  (24 GB; env: source its settings64.sh)
- Flow artifacts      : /tmp/ise_test/{led_test.ngc,led_test.ngd,led_test.bit,...}
- Batch answer file   : /tmp/ise6.batch (validated; reusable for reinstalls)
- Scratch (safe to rm) : /workspace/ise_staging, /tmp/ise_paths.txt, /tmp/test7z, /tmp/e83, /tmp/ep,
                         /root/.rsa/mykey_pvt.pem, /root/.Xilinx/ise_test
