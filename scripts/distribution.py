"""Shared release metadata and explicit inside-out code signing."""
import hashlib
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
APP_NAME = 'Palworld Mods'
APP_FILENAME = APP_NAME + '.app'
BUNDLE_ID = 'org.palworldmods.launcher'
VERSION = (ROOT / 'VERSION').read_text().strip()
if not re.fullmatch(r'\d+\.\d+\.\d+', VERSION):
    raise ValueError('VERSION must contain a semantic version.')


def signing_options(identity, hardened=True):
    if identity == '-':
        return ['--sign', '-']
    if not identity.startswith('Developer ID Application: '):
        raise ValueError('Distribution requires a Developer ID Application identity.')
    return ['--sign', identity, '--timestamp', *(['--options', 'runtime'] if hardened else [])]


def sign(path, identity, hardened=True):
    subprocess.run(['codesign', '--force', *signing_options(identity, hardened), str(path)], check=True)
    subprocess.run(['codesign', '--verify', '--strict', str(path)], check=True)


def checksum(path):
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    path.with_suffix(path.suffix + '.sha256').write_text(f'{digest}  {path.name}\n')
