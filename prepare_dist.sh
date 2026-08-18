#!/usr/bin/env bash
# One command from a fresh Unity WebGL build to a deploy-ready dist/.
#
#   bash prepare_dist.sh /mnt/c/path/to/MetallicHell/Builds/Web/v_1.4 [PART_BYTES]
#
# 1. Copies the Unity build output (Build/, TemplateData/, StreamingAssets/)
#    into dist/, replacing what's there.
# 2. Moves the two >10MiB files (*.data.unityweb, *.wasm.unityweb) out of
#    dist/Build into originals/ — the boundary can't serve them whole (10 MiB
#    wasm reply cap + 5s upstream timeout).
# 3. Splits them into 2 MiB parts + writes Build/parts/manifest.json
#    (make_parts.sh, name-agnostic).
# 4. Installs the manifest-driven index.html (index-parts-template.html) —
#    Unity's generated index.html is discarded; ours reassembles the parts
#    into Blobs in the browser.
#
# Then deploy — IMPORTANT: every rebuild needs a FRESH cid (set cid = "auto"
# in thebes.toml, and run WITHOUT --skip-install). The asset canister re-hashes
# every stored body on each commit (certified-tree rebuild), which is O(total
# state) fuel per call against a 20B-fuel ceiling — ~114 MB of state fits, but
# uploading a new build alongside the old one's parts (~230 MB peak, prune only
# runs at the end) traps with "all fuel consumed by WebAssembly" mid-upload.
# A fresh cid grows 0→114 MB and never hits the wall. (Durable fix = cache
# per-asset leaf hashes in the canister; see report to Mercatura.)
#   BIN=/home/adham/thebes-deploy-build/tools/thebes-deploy/target/release/thebes-deploy
#   THEBES_DEPLOY_FILE_DEADLINE_SECS=1800 "$BIN" deploy
#
# Unity build settings must stay: Compression=Gzip, Decompression Fallback=ON,
# Threading OFF (per Thebes/DEPLOY.md — we can't set response headers).
set -euo pipefail
cd "$(dirname "$0")"

BUILD_DIR="${1:?usage: prepare_dist.sh <unity-webgl-build-dir> [part_bytes]}"
PART_BYTES="${2:-2097152}"

[ -d "$BUILD_DIR/Build" ] || { echo "$BUILD_DIR does not look like a Unity WebGL build (no Build/)" >&2; exit 1; }

rm -rf dist originals
mkdir -p dist originals
cp -r "$BUILD_DIR/Build" dist/
[ -d "$BUILD_DIR/TemplateData" ] && cp -r "$BUILD_DIR/TemplateData" dist/
[ -d "$BUILD_DIR/StreamingAssets" ] && cp -r "$BUILD_DIR/StreamingAssets" dist/

mv dist/Build/*.data.unityweb dist/Build/*.wasm.unityweb originals/

bash make_parts.sh "$PART_BYTES"

cp index-parts-template.html dist/index.html

echo
echo "dist ready: $(du -sh dist | cut -f1), $(find dist -type f | wc -l) files"
echo "next: set cid = \"auto\" in thebes.toml (fresh cid per rebuild — fuel wall),"
echo "      then: THEBES_DEPLOY_FILE_DEADLINE_SECS=1800 <thebes-deploy> deploy"
