"""Packaging must reject incomplete or ambiguous translations."""
import json
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'scripts'))
from localization import LANGUAGES, load_catalogues


class CatalogueTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        (self.root / 'locales').mkdir()
        for language in LANGUAGES:
            (self.root / 'locales' / f'{language}.json').write_text(json.dumps({'hello': 'Hello {name}'}))
        self.changed = self.root / 'locales/fr.json'

    def test_complete(self):
        self.assertEqual(len(load_catalogues(self.root)), 17)

    def test_invalid_catalogues(self):
        for content in ['{}', '{"hello":""}', '{"hello":"Bonjour {other}"}',
                        '{"hello":"Bonjour {name}","hello":"Salut {name}"}']:
            with self.subTest(content=content):
                self.changed.write_text(content)
                with self.assertRaises(ValueError):
                    load_catalogues(self.root)

    def test_missing_language(self):
        self.changed.unlink()
        with self.assertRaises(FileNotFoundError):
            load_catalogues(self.root)


if __name__ == '__main__':
    unittest.main()
