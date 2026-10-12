#!/usr/bin/env python3
"""Check distributable source boundaries, formatting and Lua syntax."""
import pathlib
import re
import shutil
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
files = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=ROOT).decode().split('\0')
source_types = {'.cpp', '.hpp', '.mm', '.swift', '.lua', '.py', '.sh', '.command'}
forbidden = [re.compile('/' + r'Users/[^\s]+'), re.compile(r'-----BEGIN ' + r'(?:RSA |OPENSSH |EC )?PRIVATE KEY-----'),
             re.compile(r'(?:gh[pousr]_' + r'[A-Za-z0-9]{30,}|github_pat_' + r'[A-Za-z0-9_]{40,})')]
problems = []
for name in sorted(set(files) - {''}):
    path = ROOT / name
    if not path.is_file():
        continue
    if path.suffix in {'.sav', '.ips', '.crash', '.log', '.dylib', '.zip'} or name.startswith(('local/', 'build/', 'dist/', '.cache/')):
        problems.append(f'{name}: private state or generated output is tracked')
        continue
    try:
        content = path.read_text()
    except UnicodeDecodeError:
        problems.append(f'{name}: unexpected binary file')
        continue
    if path.suffix in source_types and len(content.splitlines()) > 300:
        problems.append(f'{name}: exceeds 300 source lines')
    if content and not content.endswith('\n'):
        problems.append(f'{name}: missing final newline')
    if any(line.rstrip() != line for line in content.splitlines()):
        problems.append(f'{name}: trailing whitespace')
    if any(pattern.search(content) for pattern in forbidden):
        problems.append(f'{name}: private path or credential pattern')
    if path.suffix == '.lua':
        compiler = shutil.which('luac')
        if not compiler:
            problems.append('Install Lua 5.4 to validate Lua sources')
            break
        subprocess.run([compiler, '-p', str(path)], check=True)
if problems:
    raise SystemExit('\n'.join(problems))
print(f'PASS: source boundaries, privacy patterns, file sizes and syntax ({len(set(files)) - 1} files)')
