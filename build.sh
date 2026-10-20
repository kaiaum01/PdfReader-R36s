#!/bin/sh
set -eu
cd "$(dirname "$0")"
rustup toolchain install 1.99.0 --profile minimal --target aarch64-unknown-linux-musl
CARGO_BUILD_JOBS=2 CARGO_PROFILE_RELEASE_LTO=false CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1 cargo +1.99.0 build --release --locked --target aarch64-unknown-linux-musl -p pdfcraft-r36s
mkdir -p port/pdfcraft-r36s/bin
cp target/aarch64-unknown-linux-musl/release/pdfcraft-core port/pdfcraft-r36s/bin/pdfcraft-core.aarch64
chmod +x port/PdfCraft.sh port/pdfcraft-r36s/bin/pdfcraft-core.aarch64
echo 'Compilado. Copie port/PdfCraft.sh e port/pdfcraft-r36s para a pasta ports do cartão.'
