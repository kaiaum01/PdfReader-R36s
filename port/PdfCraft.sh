#!/bin/bash
# PdfCraft R36S 0.2.2 - read-only native PDF reader for PortMaster.
# Original PDF engine: storytold / artcraft-android (MIT OR Apache-2.0).

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
GAMEDIR="$SCRIPT_DIR/pdfcraft-r36s"
mkdir -p "$GAMEDIR/conf" "$GAMEDIR/cache" "$GAMEDIR/documents"
exec > >(tee "$GAMEDIR/log.txt") 2>&1
echo "PdfCraft R36S 0.2.2"
uname -a

controlfolder=""
for candidate in /opt/system/Tools/PortMaster /opt/tools/PortMaster "${XDG_DATA_HOME:-$HOME/.local/share}/PortMaster" /roms2/ports/PortMaster /roms/ports/PortMaster /roms2/tools/PortMaster /roms/tools/PortMaster; do
    if [ -f "$candidate/control.txt" ]; then controlfolder="$candidate"; break; fi
done
if [ -z "$controlfolder" ]; then
    echo "PortMaster não encontrado. / PortMaster not found. Install or update PortMaster."
    exit 1
fi
source "$controlfolder/control.txt"
[ -f "$controlfolder/mod_${CFW_NAME}.txt" ] && source "$controlfolder/mod_${CFW_NAME}.txt"
get_controls
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"
export XDG_DATA_HOME="$GAMEDIR/conf"
export PDFCRAFT_DOCUMENTS="$GAMEDIR/documents"
export PDFCRAFT_SESSION="$GAMEDIR/cache/session-$$"
export RAYON_NUM_THREADS=2
export LP_NUM_THREADS=2
mkdir -p "$PDFCRAFT_SESSION"

finish() {
    if [ -n "${core_pid:-}" ]; then kill "$core_pid" 2>/dev/null; wait "$core_pid" 2>/dev/null; fi
    if [ -n "${keys_pid:-}" ]; then kill "$keys_pid" 2>/dev/null; fi
    rm -f "$PDFCRAFT_SESSION/request.json" "$PDFCRAFT_SESSION/request.tmp" "$PDFCRAFT_SESSION/response.json" "$PDFCRAFT_SESSION/response.tmp" "$PDFCRAFT_SESSION/ready.json" "$PDFCRAFT_SESSION/ready.tmp" "$PDFCRAFT_SESSION/page.png" "$PDFCRAFT_SESSION/page.tmp"
    rmdir "$PDFCRAFT_SESSION" 2>/dev/null
    type pm_finish >/dev/null 2>&1 && pm_finish
}
trap finish EXIT
trap 'exit 130' INT TERM

fail() {
    echo "$1"
    if type pm_message >/dev/null 2>&1; then pm_message "$1"; fi
    exit 1
}
case "$(uname -m)" in aarch64|arm64) ;; *) fail "Requer Linux ARM64/aarch64. / Requires Linux ARM64/aarch64." ;; esac

if [ ! -f "$controlfolder/runtimes/love_11.5/love.txt" ]; then
    fail "Instale LÖVE 11.5 pelo PortMaster. / Install LÖVE 11.5 in PortMaster runtime management."
fi
source "$controlfolder/runtimes/love_11.5/love.txt"
[ -x "$LOVE_BINARY" ] || fail "Reinstale LÖVE 11.5 pelo PortMaster. / Reinstall the LÖVE 11.5 runtime in PortMaster."

chmod +x "$GAMEDIR/bin/pdfcraft-core.aarch64"
"$GAMEDIR/bin/pdfcraft-core.aarch64" --version || fail "Falha no motor PDF. / PDF engine failed. Send pdfcraft-r36s/log.txt."
"$GAMEDIR/bin/pdfcraft-core.aarch64" serve "$PDFCRAFT_SESSION" &
core_pid=$!

cd "$GAMEDIR" || exit 1
if [ -n "${GPTOKEYB:-}" ]; then
    $GPTOKEYB "$LOVE_GPTK" &
    keys_pid=$!
fi
type pm_platform_helper >/dev/null 2>&1 && pm_platform_helper "$LOVE_BINARY"
$LOVE_RUN "$GAMEDIR/app"
status=$?
echo "LÖVE terminou / exited: $status"
exit "$status"
