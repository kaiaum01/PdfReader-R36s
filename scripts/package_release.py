#!/usr/bin/env python3
"""Package the compiled PortMaster app; standard library only."""
from pathlib import Path
import hashlib
import zipfile

ROOT = Path(__file__).resolve().parent.parent
PORT = ROOT / 'port'
VERSION = '0.2.2'
CORE = PORT / 'pdfcraft-r36s/bin/pdfcraft-core.aarch64'

def main():
    if not CORE.is_file():
        raise SystemExit('Run sh build.sh first: ARM64 engine not found.')
    header = CORE.read_bytes()[:20]
    if header[:4] != b'\x7fELF' or int.from_bytes(header[18:20], 'little') != 183:
        raise SystemExit('The engine must be an AArch64 ELF executable.')
    out = ROOT / 'dist'
    out.mkdir(exist_ok=True)
    archive = out / f'PdfCraft-R36S-v{VERSION}-R36S.zip'
    files = []
    for path in sorted(PORT.rglob('*')):
        rel = path.relative_to(PORT)
        if not path.is_file() or any(p in {'conf', 'cache', '__pycache__'} for p in rel.parts):
            continue
        if path.suffix == '.zip' or path.name in {'log.txt', 'state.json', 'SHA256SUMS.txt'}:
            continue
        files.append((path, rel.as_posix()))
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=6, strict_timestamps=False) as z:
        checks = []
        for path, name in files:
            data = path.read_bytes()
            info = zipfile.ZipInfo.from_file(path, name, strict_timestamps=False)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = (0o100755 if name.endswith('.sh') or path == CORE else 0o100644) << 16
            z.writestr(info, data)
            checks.append(hashlib.sha256(data).hexdigest() + '  ' + name)
        z.writestr('SHA256SUMS.txt', '\n'.join(checks) + '\n')
    with zipfile.ZipFile(archive) as z:
        if z.testzip() is not None:
            raise SystemExit('ZIP integrity check failed.')
    checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    (out / 'SHA256SUMS.txt').write_text(checksum + '  ' + archive.name + '\n')
    print(archive)

if __name__ == '__main__':
    main()
