# Architect Icons Pack

Version: 1.0.0

## Quick start

1. Choose the platform export under `PlatformExports/`.
2. Read its `README.md` and copy/import the files into your project.
3. Use `Docs/manifest.json` as the machine-readable contract.
4. Use the atlas JSON/CSV files to resolve sprite names to UV coordinates.

## Cross-platform support

This pack is designed to work for developers on Windows, Linux, and macOS. Filesystem paths are kept separate from package paths: paths inside ZIP files, JSON, CSV, and engine exports always use `/`, while each operating system handles its own local paths. The package contains no absolute developer-machine paths.

## Package contents

- `Sprites/` — individual source sprites, when enabled.
- `Atlases/` and `Docs/` — generated atlases, mappings, and metadata.
- `Previews/` — contact sheets and preview images for browsing and QA. The ZIP keeps this folder flat; its files come from the internal `Previews/full_set/` build output.
- `PlatformExports/` — platform-specific import layouts.
- `Samples/` — minimal examples, when included.

The manifest uses portable relative paths only. Texture roles are `diffuse`, `normal`, `mask`, and `emission`.

Generated with Rust Explorer v0.5.7.
