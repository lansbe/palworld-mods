#!/usr/bin/env python3
"""Build a drag-to-Applications installer without opening Finder."""
import argparse
import pathlib
import subprocess
import tempfile
from distribution import ROOT, APP_NAME, APP_FILENAME, VERSION, checksum, sign
from package_app import package_app


def image_settings(app):
    return {
        'format': 'UDZO', 'compression_level': 9, 'filesystem': 'HFS+',
        'files': [str(app)], 'symlinks': {'Applications': '/Applications'},
        'icon': str(app / 'Contents/Resources/AppIcon.icns'),
        'background': str(ROOT / 'build/distribution-assets/InstallerBackground.tiff'),
        'icon_locations': {APP_FILENAME: (180, 198), 'Applications': (500, 198)},
        'window_rect': ((240, 160), (680, 420)), 'default_view': 'icon-view',
        'show_status_bar': False, 'show_tab_view': False, 'show_toolbar': False,
        'show_pathbar': False, 'show_sidebar': False, 'show_icon_preview': False,
        'include_icon_view_settings': True, 'include_list_view_settings': False,
        'arrange_by': None, 'icon_size': 112, 'text_size': 14,
        'label_pos': 'bottom', 'hide_extension': [APP_FILENAME],
    }


def notarize(path, profile):
    subprocess.run(['xcrun', 'notarytool', 'submit', str(path),
                    '--keychain-profile', profile, '--wait'], check=True)
    subprocess.run(['xcrun', 'stapler', 'staple', str(path)], check=True)
    subprocess.run(['xcrun', 'stapler', 'validate', str(path)], check=True)


def package_dmg(identity='-', notary_profile=None):
    try:
        import dmgbuild
    except ImportError as error:
        raise RuntimeError('Install scripts/requirements-packaging.txt in a virtual environment first.') from error
    if notary_profile and identity == '-':
        raise ValueError('Notarization requires a Developer ID Application signing identity.')
    app = package_app(identity)
    # Staple the app as well as the image so a copied app can pass offline checks.
    if notary_profile:
        with tempfile.TemporaryDirectory(prefix='notary-', dir=ROOT / 'build') as temporary:
            archive = pathlib.Path(temporary) / 'Application.zip'
            subprocess.run(['ditto', '-c', '-k', '--keepParent', str(app), str(archive)], check=True)
            subprocess.run(['xcrun', 'notarytool', 'submit', str(archive),
                            '--keychain-profile', notary_profile, '--wait'], check=True)
        subprocess.run(['xcrun', 'stapler', 'staple', str(app)], check=True)
        subprocess.run(['xcrun', 'stapler', 'validate', str(app)], check=True)
    destination = ROOT / 'dist' / f'palworld-mods-{VERSION}-macos-arm64.dmg'
    with tempfile.TemporaryDirectory(prefix='dmg-package-', dir=ROOT / 'build') as temporary:
        image = pathlib.Path(temporary) / destination.name
        dmgbuild.build_dmg(str(image), APP_NAME, settings=image_settings(app))
        if identity != '-':
            sign(image, identity, hardened=False)
        if notary_profile:
            notarize(image, notary_profile)
        subprocess.run(['hdiutil', 'verify', str(image)], check=True)
        image.replace(destination)
    checksum(destination)
    print(f'Built dist/{destination.name}')
    if not notary_profile:
        print('Local build: not notarized. Gatekeeper approval may be required after downloading.')
    return destination


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sign-identity', default='-')
    parser.add_argument('--notary-profile')
    args = parser.parse_args()
    package_dmg(args.sign_identity, args.notary_profile)
