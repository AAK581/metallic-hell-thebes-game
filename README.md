# Metallic Hell — on Thebes L1

First-person horror wave-shooter (Unity 6 WebGL), served entirely from the
[Thebes](https://github.com/KYounesMercatura/Thebes-Project) sovereign L1 —
every byte of the game (engine, assets, loader page) lives in an on-chain
asset canister and is served through the chain boundary.

**Play:** https://memphis.mercaturaforum.com/_/raw/9635586163366/index.html

## What's in this repo

| Path | What |
|---|---|
| `dist/` | The deploy-ready game bundle (current build). Replaced wholesale on every new build. |
| `prepare_dist.sh` | Unity WebGL build → `dist/`: splits the two >10 MiB files into 2 MiB parts + writes `manifest.json`, installs the loader page. |
| `make_parts.sh` | The part-splitter (name-agnostic, called by prepare_dist). |
| `index-parts-template.html` | The loader page: fetches the parts, reassembles them into Blobs in the browser, hands blob: URLs to Unity. Two amber eyes brighten with download progress. |
| `thebes.toml` | Deploy manifest: validator set, boundary, canister. |
| `asset_canister.wasm` | The on-chain asset canister the bundle is installed into. |
| `push_build.sh` | One command: new Unity build → dist → commit → push. |

## Why parts?

The Thebes runtime caps a single reply append at 10 MiB and the boundary
gives each upstream fetch a 5 s budget with no Range support — so the
~100 MB `.data` and ~18 MB `.wasm` can't be served whole. They're stored as
2 MiB parts and reassembled client-side; bytes are identical, so Unity's
gzip decompression fallback works unchanged.

## Updating the build

Unity: **File ▸ Build Settings ▸ WebGL** (Compression = Gzip, Decompression
Fallback = ON, threading OFF) to `Builds/Web/v_X.Y`, then:

```bash
bash push_build.sh /mnt/c/path/to/MetallicHell/Builds/Web/v_X.Y
```

That replaces `dist/`, commits, and pushes. Then deploy to the chain:

```bash
# Fresh cid per rebuild (set cid = "auto" in thebes.toml first): the asset
# canister re-hashes all stored bodies per commit, so uploading a new build
# next to an old one hits the fuel ceiling mid-upload.
THEBES_DEPLOY_FILE_DEADLINE_SECS=1800 thebes-deploy deploy
```

The deploy takes ~30–40 min over WAN and writes the new cid back into
`thebes.toml`; the game URL changes with it.
