#!/usr/bin/env bash
# New Unity WebGL build → replace dist/ → commit → push, in one command:
#
#   bash push_build.sh /mnt/c/path/to/MetallicHell/Builds/Web/v_1.10
#
# The repo carries exactly one build (dist/ is replaced wholesale), so each
# push swaps the uploaded build for the new one.
set -euo pipefail
cd "$(dirname "$0")"

BUILD_DIR="${1:?usage: push_build.sh <unity-webgl-build-dir>}"

bash prepare_dist.sh "$BUILD_DIR"

git add -A
git commit -m "build: $(basename "$BUILD_DIR")"
git push
echo
echo "pushed $(basename "$BUILD_DIR") — dist/ replaced ($(du -sh dist | cut -f1))"
