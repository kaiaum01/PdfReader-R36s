# PdfCraft R36S — technical guide

Experimental PDF reader port using the original Rust renderer and a new LÖVE 11.5 interface. The Android UI is neither executed nor emulated.

## Architecture

`apps/pdfcraft-r36s` builds a persistent native process using the original `render`, `fonts`, `cos`, `crypt`, and `filters` components. The PDF document and parser stay in memory between requests. The UI sends JSON requests through temporary files and receives responses published using atomic renames. It renders one page at a time and does not alter source PDFs.

`port/pdfcraft-r36s/app` contains the Lua UI: file browser, reader, engine communication, drawing, and settings. The launcher starts and stops the helper process and uses PortMaster's `love_11.5` runtime.

## Building

Run `./build.sh` on Linux with rustup installed. It uses Rust 1.99.0, `aarch64-unknown-linux-musl`, `rust-lld`, and Cortex-A35 optimizations. The engine statically links the C library to avoid firmware glibc dependencies. Internet may be required to resolve dependencies on the first build. `Cargo.lock` pins versions. Android SDK, NDK, and Java are not required.

The output is `port/pdfcraft-r36s/bin/pdfcraft-core.aarch64`. Copy the files from `port` to your Ports directory, preserving the layout.

## Independent verification

`pdfcraft-core.aarch64 --version` identifies the engine.  
`pdfcraft-core.aarch64 probe sample.pdf output-folder` opens the PDF, prints JSON metadata, and exports the first page as `page.png`. On x86_64, the binary may be run using `qemu-aarch64-static`.

Previous test routines cover opening, rendering, Portuguese text extraction, landscape pages, zoom boundaries, and password-protected PDFs. CPU emulation does not predict physical R36S performance. Validate controller mapping and video drivers on the actual device.

## Scope

Reading and navigation only. PDF editing, OCR, camera functions, and text-to-speech are not implemented. The original modules not used by this reader are excluded from this reduced source tree; the original Android ZIP remains a separate upstream reference.

Original code license: MIT OR Apache-2.0. License notices and attributions are retained.
