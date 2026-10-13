"""Load and validate independently maintained localization catalogues."""
import json
import pathlib
import re

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


def load_catalogues(root=ROOT):
    folder = root / 'locales'
    catalogues = {language: json.loads((folder / f'{language}.json').read_text(), object_pairs_hook=unique_object)
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
    payload = {'languages': json.loads((ROOT / 'locales/languages.json').read_text()), 'messages': load_catalogues()}
    encoded = json.dumps(payload, ensure_ascii=False, separators=(',', ':'))
    return 'return Engine.json_decode([==[' + encoded + ']==])'


if __name__ == '__main__':
    catalogues = load_catalogues()
    print(f'PASS: {len(catalogues)} languages, {len(catalogues["en"])} keys, placeholders and nonempty translations')
