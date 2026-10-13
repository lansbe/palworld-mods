#!/usr/bin/env python3
"""Exercise the built signed update against a disposable app copy, never the live app."""
import pathlib
import plistlib
import shutil
import subprocess
import tempfile
from distribution import ROOT, APP_FILENAME, VERSION


def test_installation():
    sources = [*sorted((ROOT / 'src/update').glob('*.swift')), ROOT / 'tests/update-installation/main.swift']
    executable = ROOT / 'build/update-installation-tests'
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-warnings-as-errors', '-framework', 'CryptoKit',
                    *map(str, sources), '-o', str(executable)], check=True)
    with tempfile.TemporaryDirectory(prefix='update-integration-', dir=ROOT / 'build') as temporary:
        folder = pathlib.Path(temporary).resolve()
        app = folder / APP_FILENAME
        shutil.copytree(ROOT / 'dist' / APP_FILENAME, app)
        metadata = app / 'Contents/Info.plist'
        info = plistlib.loads(metadata.read_bytes())
        info['CFBundleShortVersionString'] = info['CFBundleVersion'] = '0.0.0'
        metadata.write_bytes(plistlib.dumps(info))
        subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True)
        stage = folder / 'stage'
        stage.mkdir()
        for source, target in [(f'palworld-mods-{VERSION}-macos-arm64.zip', 'package.zip'),
                               ('palworld-mods-update.json', 'manifest.json'), ('palworld-mods-update.sig', 'manifest.sig')]:
            shutil.copy2(ROOT / 'dist' / source, stage / target)
        subprocess.run([str(executable), str(stage), str(app), '0.0.0'], check=True)


if __name__ == '__main__':
    test_installation()
