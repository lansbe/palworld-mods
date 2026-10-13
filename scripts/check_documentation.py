#!/usr/bin/env python3
"""Validate local Markdown links and documentation screenshots without network access."""
import pathlib
import re
import subprocess
from urllib.parse import unquote, urlsplit

ROOT = pathlib.Path(__file__).resolve().parents[1]
LINK = re.compile(r'!?\[([^\]]*)\]\(([^\s)]+)(?:\s+"[^"]*")?\)')


def anchors(path):
    """Match the simple ATX headings used by this project's Markdown."""
    result, counts = set(), {}
    for line in path.read_text().splitlines():
        match = re.match(r'^#{1,6}\s+(.+?)\s*#*$', line)
        if not match:
            continue
        slug = re.sub(r'[^\w\- ]', '', match[1].lower()).replace(' ', '-')
        count = counts.get(slug, 0)
        counts[slug] = count + 1
        result.add(slug if count == 0 else f'{slug}-{count}')
    return result


def check():
    files = subprocess.check_output(
        ['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'],
        cwd=ROOT).decode().split('\0')
    problems, links, images = [], 0, 0
    for name in sorted(set(files) - {''}):
        path = ROOT / name
        if not path.is_file():
            continue
        if name.startswith('docs/screenshots/') and path.suffix == '.jpg':
            data = path.read_bytes()
            if not data.startswith(b'\xff\xd8\xff') or not data.endswith(b'\xff\xd9'):
                problems.append(f'{name}: invalid JPEG signature')
            if len(data) > 2 * 1024 * 1024:
                problems.append(f'{name}: screenshot exceeds 2 MiB')
            images += 1
        if path.suffix != '.md':
            continue
        for match in LINK.finditer(path.read_text()):
            label, reference = match.groups()
            target = urlsplit(reference.strip('<>'))
            if target.scheme or target.netloc:
                continue
            links += 1
            destination = (path.parent / unquote(target.path)).resolve() if target.path else path
            if not destination.is_relative_to(ROOT):
                problems.append(f'{name}: link leaves repository: {reference}')
            elif not destination.exists():
                problems.append(f'{name}: missing local link: {reference}')
            elif target.fragment and destination.suffix == '.md' and unquote(target.fragment) not in anchors(destination):
                problems.append(f'{name}: missing heading: {reference}')
            if match[0].startswith('!') and not label.strip():
                problems.append(f'{name}: screenshot needs descriptive alt text')
    if problems:
        raise SystemExit('\n'.join(problems))
    print(f'PASS: {links} local documentation links and {images} screenshots')


if __name__ == '__main__':
    check()
