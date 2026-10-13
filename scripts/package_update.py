#!/usr/bin/env python3
"""Build an authenticated update from the already verified release app."""
import hashlib
import json
import pathlib
import subprocess
from distribution import ROOT, APP_FILENAME, BUNDLE_ID, VERSION, checksum
from verify_package import verify_app


def package_update():
    app = ROOT / 'dist' / APP_FILENAME
    verify_app(app)
    destination = app.parent / f'palworld-mods-{VERSION}-macos-arm64.zip'
    if destination.exists():
        destination.unlink()
    subprocess.run(['/usr/bin/ditto', '-c', '-k', '--norsrc', '--keepParent', str(app), str(destination)], check=True)
    data = destination.read_bytes()
    if not 0 < len(data) <= 67_108_864:
        raise ValueError('The update archive exceeds its size limit.')
    manifest = {'schema': 1, 'version': VERSION, 'bundleIdentifier': BUNDLE_ID,
                'minimumSystemVersion': '14.0.0', 'archive': destination.name,
                'sha256': hashlib.sha256(data).hexdigest(), 'size': len(data)}
    document = app.parent / 'palworld-mods-update.json'
    document.write_text(json.dumps(manifest, sort_keys=True, separators=(',', ':')) + '\n')
    signature = document.with_suffix('.sig')
    subprocess.run(['xcrun', 'swift', str(ROOT / 'scripts/update_signer.swift'),
                    'initialize', str(ROOT / 'src/update/UpdateTrust.swift')], check=True)
    subprocess.run(['xcrun', 'swift', str(ROOT / 'scripts/update_signer.swift'),
                    'sign', str(document), str(signature)], check=True)
    checksum(destination)
    print('Built authenticated update archive and signed manifest.')
    return destination


if __name__ == '__main__':
    package_update()
