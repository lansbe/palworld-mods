#!/usr/bin/env python3
"""Verify the actual disk image, Finder layout, signatures and bundled catalogue."""
import argparse
import hashlib
import json
import pathlib
import plistlib
import subprocess
from distribution import APP_NAME, APP_FILENAME, BUNDLE_ID, VERSION


def verify_app(app):
    contents = app / 'Contents'
    info = plistlib.loads((contents / 'Info.plist').read_bytes())
    expected = {'CFBundleIdentifier': BUNDLE_ID, 'CFBundleName': APP_NAME,
                'CFBundleShortVersionString': VERSION, 'CFBundleExecutable': 'PalworldMods'}
    for key, value in expected.items():
        if info.get(key) != value:
            raise ValueError(f'Unexpected app metadata: {key}')
    resources = contents / 'Resources'
    if not (resources / info['CFBundleIconFile']).is_file():
        raise ValueError('Missing app icon.')
    for binary in [contents / 'MacOS/PalworldMods', resources / 'libPalMods.dylib', contents / 'Helpers/UpdateInstaller']:
        architectures = subprocess.check_output(['lipo', '-archs', str(binary)], text=True).strip()
        if architectures != 'arm64':
            raise ValueError('The app must contain only its supported Apple silicon build.')
        subprocess.run(['codesign', '--verify', '--strict', str(binary)], check=True)
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    catalog = resources / 'Catalog'
    for identifier in ['minimap', 'autonomy']:
        data = (catalog / f'{identifier}.json').read_bytes()
        expected_hash = (catalog / f'{identifier}.sha256').read_text().strip()
        package = json.loads(data)
        if hashlib.sha256(data).hexdigest() != expected_hash or package.get('id') != identifier:
            raise ValueError('The bundled mod catalogue failed its integrity check.')
        if package.get('api') != 1 or not package.get('files') or len(data) > 1_048_576:
            raise ValueError('The bundled mod catalogue is incomplete.')


def verify_image(image):
    from ds_store import DSStore
    expected = image.with_suffix(image.suffix + '.sha256').read_text().split()[0]
    if hashlib.sha256(image.read_bytes()).hexdigest() != expected:
        raise ValueError('Disk image checksum mismatch.')
    subprocess.run(['hdiutil', 'verify', str(image)], check=True)
    result = plistlib.loads(subprocess.check_output(
        ['hdiutil', 'attach', '-readonly', '-nobrowse', '-noautoopen', '-plist', str(image)]))
    entity = next(item for item in result['system-entities'] if 'mount-point' in item)
    mount = pathlib.Path(entity['mount-point'])
    try:
        if {item.name for item in mount.iterdir() if not item.name.startswith('.')} != {APP_FILENAME, 'Applications'}:
            raise ValueError('The installer must show only the app and Applications.')
        shortcut = mount / 'Applications'
        if not shortcut.is_symlink() or shortcut.readlink() != pathlib.Path('/Applications'):
            raise ValueError('The installation target must be the system Applications folder.')
        verify_app(mount / APP_FILENAME)
        with DSStore.open(str(mount / '.DS_Store'), 'r') as store:
            if store['.']['icvl'][1] != b'icnv':
                raise ValueError('The installer must open in icon view.')
            for name, position in {APP_FILENAME: (180, 198), 'Applications': (500, 198)}.items():
                if store[name]['Iloc'] != position:
                    raise ValueError('Unexpected installer icon position.')
            if store['.']['icvp']['iconSize'] != 112:
                raise ValueError('Unexpected installer icon size.')
        print('PASS: disk image, drag target, app signatures, Finder layout and bundled mods')
    finally:
        subprocess.run(['hdiutil', 'detach', entity['dev-entry']], check=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('image', type=pathlib.Path)
    verify_image(parser.parse_args().image)
