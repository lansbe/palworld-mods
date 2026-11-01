#!/usr/bin/env python3
"""Assemble a self-contained macOS app with an offline mod catalogue."""
import hashlib
import argparse
import json
import pathlib
import plistlib
import shutil
import subprocess
import tempfile
import re
from build import ROOT, build
from localization import load_catalogues, copy_catalogues
from package_io import SourceTree, MAX_BYTES, write_catalogue
from distribution import APP_NAME, APP_FILENAME, BUNDLE_ID, VERSION, sign, signing_options


def package_mod(folder, output, expected_id):
    if not isinstance(expected_id, str) or not re.fullmatch(r'[a-z][a-z0-9-]{0,63}', expected_id):
        raise ValueError('Invalid expected package identifier')
    with SourceTree(folder) as source:
        manifest = json.loads(source.read_text('manifest.json'))
        if not isinstance(manifest, dict) or manifest.get('id') != expected_id:
            raise ValueError('Unexpected package identifier')
        manifest['licenseText'] = source.read_text('LICENSE')
        if source.has_directory('locales'):
            manifest['translations'] = load_catalogues(read_text=source.read_text)
        manifest['files'] = {}
        for name, content in source.lua_files():
            if name in manifest['files']:
                raise ValueError('Ambiguous package module name')
            manifest['files'][name] = content
    data = json.dumps(manifest, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()
    if len(data) > MAX_BYTES:
        raise ValueError('Package catalogue exceeds the size limit')
    write_catalogue(output, expected_id, data, (hashlib.sha256(data).hexdigest() + '\n').encode())


def package_app(identity='-'):
    signing_options(identity)
    for name in ['palworld-mod-minimap', 'palworld-mod-autonomy']:
        if not (ROOT.parent / name / 'manifest.json').is_file():
            raise RuntimeError(f'Place {name} beside this repository before packaging.')
    build()
    assets = ROOT / 'build/distribution-assets'
    subprocess.run(['xcrun', 'swift', str(ROOT / 'scripts/assets.swift'), str(assets)], check=True)
    subprocess.run(['xcrun', 'iconutil', '--convert', 'icns', str(assets / 'AppIcon.iconset'),
                    '--output', str(assets / 'AppIcon.icns')], check=True)
    (ROOT / 'dist').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='app-package-', dir=ROOT / 'build') as staging:
        app = pathlib.Path(staging) / APP_FILENAME
        assemble(app, assets, identity)
        destination = ROOT / 'dist' / APP_FILENAME
        if destination.exists():
            shutil.rmtree(destination)
        shutil.move(app, destination)
    print(f'Built dist/{APP_FILENAME}')
    return destination


def assemble(app, assets, identity):
    contents = app / 'Contents'
    executable = contents / 'MacOS'
    resources = contents / 'Resources'
    for folder in [executable, contents / 'Helpers', resources / 'Catalog']:
        folder.mkdir(parents=True, exist_ok=True)
    keychain = ROOT / 'build/update-keychain.o'
    subprocess.run(['xcrun', 'clang', '-target', 'arm64-apple-macos14.0', '-O2', '-Wall', '-Wextra', '-Werror',
                    f'-ffile-prefix-map={ROOT}=.', '-c', str(ROOT / 'src/launcher/UpdateKeychain.c'),
                    '-o', str(keychain)], check=True)
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-O', '-warnings-as-errors',
                    '-file-prefix-map', f'{ROOT}=.', '-debug-prefix-map', f'{ROOT}=.',
                    '-target', 'arm64-apple-macos14.0', '-import-objc-header', str(ROOT / 'src/launcher/UpdateKeychain.h'),
                    str(keychain), '-framework', 'AppKit', '-framework', 'CryptoKit', '-framework', 'Security',
                    *map(str, sorted((ROOT / 'src/update').glob('*.swift'))),
                    *map(str, sorted((ROOT / 'src/launcher').glob('*.swift'))),
                    '-o', str(executable / 'PalworldMods')], check=True)
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-O', '-warnings-as-errors',
                    '-file-prefix-map', f'{ROOT}=.', '-target', 'arm64-apple-macos14.0',
                    '-framework', 'AppKit', '-framework', 'CryptoKit',
                    *map(str, sorted((ROOT / 'src/update').glob('*.swift'))),
                    str(ROOT / 'src/update-installer/main.swift'),
                    '-o', str(contents / 'Helpers/UpdateInstaller')], check=True)
    shutil.copy2(ROOT / 'build/libPalMods.dylib', resources)
    shutil.copy2(ROOT / 'THIRD_PARTY_NOTICES.md', resources)
    shutil.copy2(ROOT / 'LICENSE', resources)
    shutil.copy2(assets / 'AppIcon.icns', resources)
    copy_catalogues(resources / 'Locales')
    for name in ['palworld-mod-minimap', 'palworld-mod-autonomy']:
        package_mod(ROOT.parent / name, resources / 'Catalog', name.removeprefix('palworld-mod-'))
    metadata = {'CFBundleIdentifier': BUNDLE_ID, 'CFBundleName': APP_NAME,
                'CFBundleDisplayName': APP_NAME, 'CFBundleExecutable': 'PalworldMods',
                'CFBundlePackageType': 'APPL', 'CFBundleShortVersionString': VERSION,
                'CFBundleVersion': VERSION, 'CFBundleIconFile': 'AppIcon.icns',
                'LSMinimumSystemVersion': '14.0', 'LSUIElement': True,
                'LSArchitecturePriority': ['arm64'], 'NSHighResolutionCapable': True}
    (contents / 'Info.plist').write_bytes(plistlib.dumps(metadata))
    sign(resources / 'libPalMods.dylib', identity)
    sign(contents / 'Helpers/UpdateInstaller', identity)
    sign(app, identity)
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sign-identity', default='-')
    package_app(parser.parse_args().sign_identity)
