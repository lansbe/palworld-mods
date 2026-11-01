"""Load and validate independently maintained localization catalogues."""
import json
import pathlib
import re
from generated_source import lua_string
from package_io import SourceTree

ROOT = pathlib.Path(__file__).resolve().parents[1]
LANGUAGES = ['en', 'fr', 'de', 'es', 'es-419', 'it', 'pt-BR', 'pl', 'ru',
             'tr', 'id', 'vi', 'th', 'ja', 'ko', 'zh-Hans', 'zh-Hant']


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f'Duplicate translation key: {key}')
        result[key] = value
    return result


def load_catalogues(root=ROOT, *, read_text=None):
    if read_text is None:
        with SourceTree(root) as source:
            return load_catalogues(read_text=source.read_text)
    reader = read_text
    catalogues = {language: json.loads(reader(f'locales/{language}.json'), object_pairs_hook=unique_object)
                  for language in LANGUAGES}
    reference = catalogues['en']
    for language, messages in catalogues.items():
        if set(messages) != set(reference):
            raise ValueError(f'{language}: missing or extra translation keys')
        for key, text in messages.items():
            if not isinstance(text, str) or not text.strip():
                raise ValueError(f'{language}/{key}: empty translation')
            if sorted(re.findall(r'\{([\w]+)\}', text)) != sorted(re.findall(r'\{([\w]+)\}', reference[key])):
                raise ValueError(f'{language}/{key}: placeholder mismatch')
    return catalogues


def embedded_module():
    with SourceTree(ROOT) as source:
        payload = {'languages': json.loads(source.read_text('locales/languages.json')),
                   'messages': load_catalogues(read_text=source.read_text)}
    encoded = json.dumps(payload, ensure_ascii=False, separators=(',', ':'))
    return 'return Engine.json_decode(' + lua_string(encoded) + ')'


def copy_catalogues(destination):
    with SourceTree(ROOT) as source:
        catalogues = load_catalogues(read_text=source.read_text)
        languages = json.loads(source.read_text('locales/languages.json'))
    destination.mkdir()
    for name, value in [('languages', languages), *catalogues.items()]:
        (destination / (name + '.json')).write_text(json.dumps(value, ensure_ascii=False), encoding='utf-8')


if __name__ == '__main__':
    catalogues = load_catalogues()
    print(f'PASS: {len(catalogues)} languages, {len(catalogues["en"])} keys, placeholders and nonempty translations')
