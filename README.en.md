# PdfCraft R36S

**Language:** English · [Português (Brasil)](README.pt-BR.md)

An experimental PDF reader for the **R36S handheld**, featuring a **Lua / LÖVE 11.5** user interface and a native **Rust (ARM64)** rendering engine. This repository contains the **0.2 UI redesign (test build)**.

> **Status:** Experimental. The updated UI has not yet been fully validated on actual R36S hardware. This is a **PDF reader**, not a PDF editor.

## Features

- Browse folders and select PDFs on the console's storage.
- Open documents and navigate between pages.
- Dark interface with blue accents, library, recent files, and favorites.
- Fit-to-screen, text reading mode, night mode, and page indicators.
- Interface zoom levels up to **32×**, subject to rendering limits.
- Resume from the last read page.
- Basic support for password-protected documents.

### A0 drawing zoom: important limitation

The UI supports zoom settings up to 32×, but **the bundled renderer still limits rendered image dimensions**. Increasing zoom may therefore **not reveal additional detail** in A0 engineering sheets. High-resolution region/tile rendering requires additional Rust development and recompilation; it is **not a finished feature**.

## Repository layout

```text
PdfCraft-R36S/
├── README.md                    Language selector
├── README.pt-BR.md / README.en.md
├── .gitignore
├── build.sh                     ARM64 engine build script
├── Cargo.toml / Cargo.lock      Rust workspace and dependencies
├── .cargo/config.toml           Target configuration
├── apps/pdfcraft-r36s/          PDF engine and JSON protocol
├── crates/                      PDF processing libraries
├── assets/                      Engine assets (fonts not in this ZIP)
├── port/
│   ├── PdfCraft.sh              PortMaster launcher
│   └── pdfcraft-r36s/
│       ├── app/                 Lua UI (main, ui, reader, backend, json)
│       ├── port.json            PortMaster metadata
│       └── licenses/            Third-party licenses and notices
└── LICENSE-MIT / LICENSE-APACHE / NOTICE
```

## Installing on the R36S

You must **build the ARM64 engine** or obtain a compatible prebuilt binary. This source archive does **not** contain the compiled ARM64 executable.

1. Install or update **PortMaster** on the handheld.
2. Install the **LÖVE 11.5** runtime through PortMaster runtime management.
3. On a Linux computer, build the engine as described below.
4. Copy **`port/PdfCraft.sh`** and the entire **`port/pdfcraft-r36s/`** directory to your SD card's **`ports`** folder, keeping their relative paths.
5. Place PDF files in `ports/pdfcraft-r36s/documents/` or browse to them in the app.
6. Launch **PdfCraft** from the console's Ports menu.

The launcher checks for ARM64 and the runtime, starts the Rust engine and the Lua UI, and writes runtime logs to `pdfcraft-r36s/log.txt`.

## Building the Rust engine

Requirements: Linux, `rustup`, Cargo, internet access for dependencies, and the `aarch64-unknown-linux-musl` target. `build.sh` uses **Rust 1.99.0** and `rust-lld` and produces `pdfcraft-core.aarch64`.

```bash
chmod +x build.sh
./build.sh
```

The resulting binary is copied to `port/pdfcraft-r36s/bin/pdfcraft-core.aarch64`. The Lua UI does not need a separate compilation step. **Note:** third-party font assets are excluded from this source archive. If your build requires files in `assets/fonts/`, obtain them from their legitimate sources and comply with the relevant licenses in `assets/fonts/` and `port/pdfcraft-r36s/licenses/`.

## Controls

The app is designed for gamepad input. Contextual hints are shown in the footer. In general, the D-pad navigates menus or pans the page, **A** confirms, **B** goes back, **L/R** switch pages, and zoom shortcuts are shown in the reader. Button mappings can differ between firmware versions; the UI includes an A/B swap option.

## Known limitations

- High-definition region-based zoom for A0 PDFs is **not** yet integrated into the shipped engine.
- Scanned PDFs without a text layer do not support OCR.
- PDF editing, signing, merging, and export are not implemented.
- Automatic library thumbnails and full-document search are not guaranteed in this build.
- Performance and loading time depend on PDF complexity and available memory.
- Controls and performance still need final validation on physical hardware.

## Testing and troubleshooting

On a compatible ARM64 Linux environment, check the engine using:

```bash
./port/pdfcraft-r36s/bin/pdfcraft-core.aarch64 --version
```

The `probe` command can inspect a PDF in a test environment; see [README-R36S.en.md](README-R36S.en.md). When reporting an issue, include firmware and PortMaster versions, PDF characteristics, and relevant `log.txt` excerpts without exposing private documents.

## Credits and licenses

The Rust engine uses components originating from **artcraft-android / storytold**, licensed under **MIT OR Apache-2.0**, as noted in the license and attribution files. Third-party dependencies have their own licenses documented in `ATTRIBUTION.md`, `ATTRIBUTION.toml`, and `port/pdfcraft-r36s/licenses/`. Preserve copyright and license notices when redistributing.

The UI and R36S integration were adapted for PdfCraft. Review individual component licenses and credits before publishing binaries.
