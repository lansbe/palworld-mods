#!/usr/bin/env python3
"""Assemble a self-contained macOS app with an offline mod catalogue."""
import hashlib
import json
import pathlib
import plistlib
import shutil
import subprocess
from build import ROOT, build


def package_mod(folder, output):
    manifest = json.loads((folder / 'manifest.json').read_text())
    manifest['files'] = {
        '.'.join(path.relative_to(folder / 'src').with_suffix('').parts): path.read_text()
        for path in sorted((folder / 'src').rglob('*.lua'))
    }
    data = json.dumps(manifest, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()
    destination = output / (manifest['id'] + '.json')
    destination.write_bytes(data)
    destination.with_suffix('.sha256').write_text(hashlib.sha256(data).hexdigest() + '\n')


def main():
    build()
    app = ROOT / 'dist/Palworld.app'
    contents = app / 'Contents'
    executable = contents / 'MacOS'
    resources = contents / 'Resources'
    for folder in [executable, resources / 'Catalog']:
        folder.mkdir(parents=True, exist_ok=True)
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-O', '-warnings-as-errors',
                    '-target', 'arm64-apple-macos14.0', '-framework', 'AppKit', '-framework', 'CryptoKit',
                    *map(str, sorted((ROOT / 'src/launcher').glob('*.swift'))),
                    '-o', str(executable / 'PalworldMods')], check=True)
    shutil.copy2(ROOT / 'build/libPalMods.dylib', resources)
    shutil.copy2(ROOT / 'THIRD_PARTY_NOTICES.md', resources)
    shutil.copy2(ROOT / 'LICENSE', resources)
    for name in ['palworld-mod-minimap', 'palworld-mod-autonomy']:
        package_mod(ROOT.parent / name, resources / 'Catalog')
    metadata = {'CFBundleIdentifier': 'org.palworldmods.launcher', 'CFBundleName': 'Palworld',
                'CFBundleDisplayName': 'Palworld', 'CFBundleExecutable': 'PalworldMods',
                'CFBundlePackageType': 'APPL', 'CFBundleShortVersionString': '0.1.0',
                'CFBundleVersion': '1', 'LSMinimumSystemVersion': '14.0', 'LSUIElement': True}
    (contents / 'Info.plist').write_bytes(plistlib.dumps(metadata))
    subprocess.run(['codesign', '--force', '--deep', '--sign', '-', str(app)], check=True)
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    shutil.copy2(ROOT / 'scripts/Install.command', ROOT / 'dist/Install.command')
    print('Built dist/Palworld.app')


if __name__ == '__main__':
    main()
