#!/usr/bin/env python3
"""Require complete, consistent catalogues and keyed interface text in every feature."""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
LANGUAGES = {'en', 'fr', 'de', 'es', 'es-419', 'it', 'pt-BR', 'pl', 'ru',
             'tr', 'id', 'vi', 'th', 'ja', 'ko', 'zh-Hans', 'zh-Hant'}
folder = ROOT / 'locales'
paths = {path.stem: path for path in folder.glob('*.json') if path.stem != 'languages'}
assert set(paths) == LANGUAGES, 'Every supported language must have a catalogue'
def unique_object(pairs):
    result = {}
    for key, value in pairs:
        assert key not in result, f'Duplicate translation key: {key}'
        result[key] = value
    return result


base = json.loads(paths['en'].read_text(), object_pairs_hook=unique_object)
for language, path in paths.items():
    messages = json.loads(path.read_text(), object_pairs_hook=unique_object)
    assert set(messages) == set(base), f'{language}: missing or extra keys'
    for key, text in messages.items():
        assert isinstance(text, str) and text.strip(), f'{language}/{key}: empty translation'
        assert sorted(re.findall(r'\{(\w+)\}', text)) == sorted(re.findall(r'\{(\w+)\}', base[key])), f'{language}/{key}: placeholders differ'
references = set()
for path in (ROOT / 'src').rglob('*'):
    if not path.is_file() or path.suffix not in {'.lua', '.swift'}:
        continue
    source = path.read_text()
    references.update(re.findall(r'''(?:I18n\.core|L10n\.text|Text\.message|api\.translate)\(['"]([^'"]+)['"]''', source))
    references.update(re.findall(r"(?:label|hint)='((?:settings|hint)\.[^']+)'", source))
    for content in re.findall(r'optionKeys=\{([^}]+)\}', source):
        references.update(re.findall(r"'([^']+)'", content))
    if path.name in {'fields.lua', 'settings.lua'} and 'key=' in source:
        for label in re.findall(r"label='([^']+)'", source):
            assert label in base, f'{path.name}: use a catalogue key, not a literal label: {label}'
    if path.name == 'Tools.swift':
        for description in re.findall(r'description: "([^"]+)"', source):
            assert description in base, f'Tool description must be localized: {description}'
    if path.name == 'menu.lua':
        assert not re.search(r"(?:action|begin|Native\.sidebar)\([^\n]*,'[A-Z][a-z ]+'", source), 'Menu labels must use localization keys'
assert references.issubset(base), 'Unknown translation keys: ' + ', '.join(sorted(references - set(base)))
print(f'PASS: localization coverage for {len(paths)} languages and {len(base)} keys')
