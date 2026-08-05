#!/usr/bin/env bash
# Split the >10MiB Unity build files into boundary-servable parts.
#
# Why: the Thebes wasm runtime caps a single http_request reply append at
# 10 MiB (egypt-wasm/src/host.rs MAX_ALLOC) and the boundary has a 5s total
# upstream fetch timeout with no Range support — so any served asset must be
# well under 10 MiB AND fetchable over WAN in <5s. Probed on the live WAN:
# 2 MiB serves in ~1.5s. We split the big files into PART_BYTES pieces; the
# manifest-driven index.html fetches the parts, reassembles Blobs, and hands
# blob: URLs to the Unity loader.
#
# Auto-detects build names from originals/*.data.unityweb — works for any
# build name (v_1.3thebes, v_1.4, ...). The two big files must live in
# originals/ (prepare_dist.sh puts them there).
#
# Usage: bash make_parts.sh [PART_BYTES]   (default 2 MiB)
set -euo pipefail
cd "$(dirname "$0")"

PART_BYTES="${1:-2097152}"
SRC_DIR="originals"
OUT_DIR="dist/Build/parts"

DATA=$(basename "$(ls "$SRC_DIR"/*.data.unityweb 2>/dev/null | head -1)") || true
WASM=$(basename "$(ls "$SRC_DIR"/*.wasm.unityweb 2>/dev/null | head -1)") || true
[ -n "$DATA" ] && [ -n "$WASM" ] || { echo "need $SRC_DIR/*.data.unityweb and *.wasm.unityweb" >&2; exit 1; }
LOADER=$(basename "$(ls dist/Build/*.loader.js | head -1)")
FRAMEWORK=$(basename "$(ls dist/Build/*.framework.js.unityweb | head -1)")

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
for f in "$DATA" "$WASM"; do
  split -b "$PART_BYTES" -d -a 3 "$SRC_DIR/$f" "$OUT_DIR/$f."
done

python3 - "$PART_BYTES" "$SRC_DIR" "$OUT_DIR" "$DATA" "$WASM" "$LOADER" "$FRAMEWORK" <<'PY'
import hashlib, json, os, sys
part_bytes, src, out, data, wasm, loader, framework = int(sys.argv[1]), *sys.argv[2:]
def entry(name):
    size = os.path.getsize(os.path.join(src, name))
    return {"file": name, "bytes": size, "parts": (size + part_bytes - 1) // part_bytes}
h = hashlib.sha256()
for name in (data, wasm):
    with open(os.path.join(src, name), "rb") as f:
        while True:
            b = f.read(1 << 20)
            if not b: break
            h.update(b)
manifest = {
    "version": h.hexdigest()[:12],
    "partBytes": part_bytes,
    "loader": "Build/" + loader,
    "framework": "Build/" + framework,
    "data": entry(data),
    "wasm": entry(wasm),
}
with open(os.path.join(out, "manifest.json"), "w") as f:
    json.dump(manifest, f, indent=1)
print(json.dumps(manifest, indent=1))
PY

echo
echo "→ $(ls "$OUT_DIR" | wc -l) files in $OUT_DIR ($(du -sh "$OUT_DIR" | cut -f1))"
