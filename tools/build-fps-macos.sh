#!/bin/sh
# Local development bundle; uses this Mac's Homebrew libraries, not a release package.
set -eu
cd "$(dirname "$0")/.."
gmake -j8 DISCORD_SDK=0 COOPNET=0 UPDATER=0 USE_APP=0 'CPP=clang -E -P -x c'
python3 - <<'PY'
from pathlib import Path
import plistlib
import shutil

root = Path('build/us_pc').resolve()
app = root / 'Mario FPS.app' / 'Contents'
(app / 'MacOS').mkdir(parents=True, exist_ok=True)
(app / 'Resources').mkdir(exist_ok=True)
shutil.copy2(root / 'sm64coopdx', app / 'MacOS' / 'sm64coopdx')
for name in ('mods', 'lang', 'dynos', 'palettes'):
    target = app / 'Resources' / name
    if not target.exists():
        target.symlink_to(root / name, target_is_directory=True)
rom = app / 'MacOS' / 'baserom.us.z64'
if not rom.is_symlink() and not rom.exists():
    rom.symlink_to(root / 'baserom.us.z64')
with (app / 'Info.plist').open('wb') as f:
    plistlib.dump(dict(CFBundleExecutable='sm64coopdx', CFBundleIdentifier='local.sm64.fps',
                      CFBundleName='Mario FPS', CFBundleDisplayName='Mario FPS',
                      CFBundlePackageType='APPL'), f)
print('Built:', app.parent)
PY
