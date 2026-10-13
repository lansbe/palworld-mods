#!/usr/bin/env python3
"""Run updater behavior tests without credentials, a game or a network connection."""
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
output = ROOT / 'build/update-tests'
output.parent.mkdir(exist_ok=True)
sources = sorted((ROOT / 'src/update').glob('*.swift'))
sources += [ROOT / 'src/launcher/UpdateNetwork.swift', ROOT / 'src/launcher/UpdateStore.swift', ROOT / 'tests/update/main.swift']
subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-warnings-as-errors', '-framework', 'CryptoKit',
                *map(str, sources), '-o', str(output)], check=True)
subprocess.run([str(output)], check=True)
