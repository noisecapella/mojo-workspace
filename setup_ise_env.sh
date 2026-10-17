#!/usr/bin/env bash
#
# setup_ise_env.sh — automate the prerequisite installation for building and
# flashing Mojo v3 bitstreams in this Debian bookworm container.
#
# Based on the verified procedure in /workspace/mojo-led-test-NOTES.md
# ("REINSTALLING ISE 14.7" — verified working 2026-10-16, ~6-7 min, exit 0).
#
# What it does:
#   1. apt system deps for the ISE 14.7 installer (xauth, xvfb, libmotif-dev,
#      fontconfig, xfonts-75dpi, xfonts-100dpi, fonts-freefont-ttf, p7zip-full)
#   2. libtinfo5 + libncurses5 via local .debs (NOT in bookworm repos)
#   3. pyserial (via pip, --break-system-packages) for the flasher
#   4. Stage the ISE installer: extract part-1 (.tar) to a fresh tree and drop
#      the part-2/-3/-4 .zip.xz alongside it (the layout batchxsetup expects)
#   5. ISE 14.7 batch install (batchxsetup under xvfb) -> /opt/Xilinx
#   6. Install /workspace/Xilinx.lic into /root/.Xilinx/ and $XILINX/data/
#   7. Verify xst/ngdbuild/map/par/trce/bitgen are on PATH
#
# The script is idempotent: it is a no-op if the packages and ISE are already
# installed, so it is safe to run unconditionally in a Dockerfile.
#
# Run as root, or as a user with passwordless sudo (the 'node' user in this
# container has both).

set -eu
# NOTE: -u (nounset) is deliberately NOT enabled: the ISE settings64.sh scripts
# reference unset variables (e.g. $LD_ASSUME_KERNEL, $_), which -u rejects.

# ---------------------------------------------------------------- config ----
WORKSPACE="${WORKSPACE:-/workspace}"
# Installer source: part-1 is a .tar that we extract; parts 2/3/4 are .zip.xz.
# All live directly in $WORKSPACE (see .gitignore — none are committed).
ISE_TAR="${ISE_TAR:-${WORKSPACE}/Xilinx_ISE_DS_14.7_1015_1-1.tar}"
ISE_PARTS=("${WORKSPACE}/Xilinx_ISE_DS_14.7_1015_1-2.zip.xz" \
           "${WORKSPACE}/Xilinx_ISE_DS_14.7_1015_1-3.zip.xz" \
           "${WORKSPACE}/Xilinx_ISE_DS_14.7_1015_1-4.zip.xz")
# Where we stage the unpacked part-1 tree + parts (fresh each install).
ISE_SRC="${ISE_SRC:-${WORKSPACE}/xilinx_ise}"
LICENSE="${LICENSE:-${WORKSPACE}/Xilinx.lic}"        # node-locked WebPack license
DEST="${DEST:-/opt/Xilinx}"                         # ISE install destination
BATCH_FILE="${BATCH_FILE:-/tmp/ise6.batch}"
INSTALL_LOG="${INSTALL_LOG:-/tmp/ise_install.log}"

TINFO_DEB="${WORKSPACE}/libtinfo5_6.4-4_amd64.deb"
NCURSES_DEB="${WORKSPACE}/libncurses5_6.4-4_amd64.deb"

# ---------------------------------------------------------------- helpers ---
log() { printf '\n\033[1;34m== %s ==\033[0m\n' "$*"; }
die() { printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

# Privilege wrapper: use sudo only if not already root and it works passwordless.
if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
elif sudo -n true 2>/dev/null; then
  SUDO="sudo"
else
  die "must run as root or with passwordless sudo"
fi

apt_get() { $SUDO apt-get "$@"; }
dpkg_i()  { $SUDO dpkg -i "$@"; }
run_sudo() { if [ -n "$SUDO" ]; then $SUDO "$@"; else "$@"; fi; }

# ------------------------------------------------------- 1. apt dependencies
log "1/7 apt system dependencies"
apt_get update -qq
apt_get install -y -qq --no-install-recommends \
    xauth xvfb libmotif-dev fontconfig \
    xfonts-75dpi xfonts-100dpi fonts-freefont-ttf \
    p7zip-full

# -------------------------------------------- 2. libtinfo5 / libncurses5 debs
# NOT available in bookworm; use the local debs. libtinfo5 first (dependency).
log "2/7 libtinfo5 + libncurses5 (local debs, not in bookworm)"
if dpkg -s libtinfo5 >/dev/null 2>&1 && dpkg -s libncurses5 >/dev/null 2>&1; then
    echo "libtinfo5/libncurses5 already installed — skipping"
else
    [ -f "$TINFO_DEB" ]   || die "missing $TINFO_DEB"
    [ -f "$NCURSES_DEB" ] || die "missing $NCURSES_DEB"
    dpkg_i "$TINFO_DEB"
    dpkg_i "$NCURSES_DEB"
fi

# ---------------------------------------------------------------- 3. pyserial
log "3/7 pyserial (flasher dependency)"
if python3 -c 'import serial' >/dev/null 2>&1; then
    echo "pyserial already installed — skipping"
else
    # pip may be missing in a bare image; bootstrap with ensurepip if needed.
    if ! command -v pip3 >/dev/null 2>&1; then
        python3 -m ensurepip --upgrade || apt_get install -y -qq python3-pip
    fi
    pip3 install --break-system-packages --no-cache-dir pyserial
fi
python3 -c 'import serial; print("pyserial", serial.__version__)'

# --------------------------------------------- 4. stage the installer tree
# Extract part-1 (.tar) into a fresh $ISE_SRC and drop parts 2/3/4 alongside it.
# This is the exact layout the verified install used (part-1 tree + the three
# .zip.xz in the same dir). Redone on every (re)install so the tree is pristine.
log "4/7 stage ISE installer tree -> ${ISE_SRC}"
[ -f "$ISE_TAR" ] || die "missing part-1 tar: $ISE_TAR"
for part in "${ISE_PARTS[@]}"; do
    [ -f "$part" ] || die "missing installer part: $part"
done
run_sudo rm -rf "$ISE_SRC"
run_sudo mkdir -p "$ISE_SRC"
run_sudo chown "$(id -un):$(id -gn)" "$ISE_SRC"
tar xf "$ISE_TAR" -C "$ISE_SRC"
cp "${ISE_PARTS[@]}" "$ISE_SRC/"
[ -x "${ISE_SRC}/bin/lin64/batchxsetup" ] || die "extraction failed: ${ISE_SRC}/bin/lin64/batchxsetup missing"
echo "  staged: $(du -sh "$ISE_SRC" | cut -f1) in $ISE_SRC"

# --------------------------------------------------- 5. ISE 14.7 batch install
log "5/7 ISE 14.7 batch install -> ${DEST}"
if [ -f "${DEST}/14.7/ISE_DS/settings64.sh" ] && [ -x "${DEST}/14.7/ISE_DS/ISE/bin/lin64/bitgen" ]; then
    echo "ISE 14.7 already installed — skipping"
else

    # Batch answer file (verified 2026-10-16). `downloadlocation_dir` is the
    # critical key: part-1's idata/ holds only ~60 of ~200 drop archives; the
    # rest live in the part-2/-3/-4 .zip.xz files. Without it the install dies
    # on "Unable to open archive .../drops/ise_0032.zip.xz".
    cat > "$BATCH_FILE" <<EOF
eula_accepted=Y
destination=${DEST}
downloadlocation_dir=${ISE_SRC}
use_multiple_cores=Y
EOF

    # Clean any partial install, then run under xvfb. LD_LIBRARY_PATH is
    # required (engine libs are not in the default loader path, otherwise
    # "libwicclient.so: cannot open shared object file"). `yes N |` auto-answers
    # any stray "Retry (Y/N):" with N instead of hanging. ~6-7 min, ~24 GB.
    # The destination path must be pre-created (the installer refuses to create
    # it itself when running as non-root: "Could not create destination path").
    $SUDO rm -rf "$DEST"
    $SUDO mkdir -p "$DEST"
    $SUDO chown -R "$(id -un):$(id -gn)" "$DEST"
    ( cd "$ISE_SRC" && \
      yes N | xvfb-run -a env LD_LIBRARY_PATH="${ISE_SRC}/lib/lin64" \
          ./bin/lin64/batchxsetup --batch "$BATCH_FILE" > "$INSTALL_LOG" 2>&1 )
    # Success is defined by the completion message in the log (batchxsetup's
    # own exit code is not reliable here). Check the log, then the tree.
    if ! grep -q "Installation is complete." "$INSTALL_LOG"; then
        tail -n 40 "$INSTALL_LOG" >&2
        die "ISE batch install failed (see $INSTALL_LOG)"
    fi
    [ -x "${DEST}/14.7/ISE_DS/ISE/bin/lin64/bitgen" ] \
        || die "install log says complete but $DEST/14.7/ISE_DS/ISE/bin/lin64/bitgen missing"
fi

# ---------------------------------------------------------------- 5. license
log "6/7 install license"
[ -f "$LICENSE" ] || die "missing $LICENSE"
$SUDO mkdir -p /root/.Xilinx
$SUDO cp "$LICENSE" /root/.Xilinx/Xilinx.lic
$SUDO cp "$LICENSE" "${DEST}/14.7/ISE_DS/ISE/data/Xilinx.lic"

# ------------------------------------------------------------------ 6. verify
log "7/7 verify ISE tools present"
# (settings64.sh is legacy and hostile to `set -u`; it is not sourced here —
# we verify the tool binaries directly. Users activate the env per-build with
# `source ${DEST}/14.7/ISE_DS/settings64.sh`.)
ISE_BIN="${DEST}/14.7/ISE_DS/ISE/bin/lin64"
missing=0
for tool in xst ngdbuild map par trce bitgen; do
    if [ -x "${ISE_BIN}/${tool}" ]; then
        echo "  ok: $tool (${ISE_BIN}/${tool})"
    else
        echo "  MISSING: $tool" >&2
        missing=1
    fi
done
[ "$missing" -eq 0 ] || die "one or more ISE tools missing from ${ISE_BIN}"

log "done — ISE 14.7 environment ready"
echo "Activate with:  source ${DEST}/14.7/ISE_DS/settings64.sh"
