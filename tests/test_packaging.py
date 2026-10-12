"""Distribution contracts that do not require a game installation or signing credentials."""
import hashlib
import json
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'scripts'))
from distribution import APP_FILENAME, checksum, signing_options
from package_app import package_mod
from package_dmg import image_settings


class PackagingTests(unittest.TestCase):
    def test_installer_cannot_replace_the_licensed_game(self):
        self.assertNotEqual(APP_FILENAME, 'Palworld.app')
        settings = image_settings(pathlib.Path(APP_FILENAME))
        self.assertEqual(settings['symlinks'], {'Applications': '/Applications'})
        self.assertEqual(settings['files'], [APP_FILENAME])
        self.assertEqual(set(settings['icon_locations']), {APP_FILENAME, 'Applications'})
        self.assertFalse(settings['show_toolbar'])

    def test_inappropriate_signing_certificates_are_rejected(self):
        for identity in ['', 'Apple Development: Example', 'Apple Distribution: Example']:
            with self.subTest(identity=identity), self.assertRaises(ValueError):
                signing_options(identity)
        self.assertEqual(signing_options('-'), ['--sign', '-'])
        options = signing_options('Developer ID Application: Example')
        self.assertIn('--timestamp', options)
        self.assertIn('runtime', options)
        self.assertNotIn('runtime', signing_options('Developer ID Application: Example', hardened=False))

    def test_catalogue_is_self_contained_and_checksum_matches_exact_bytes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            folder = root / 'mod'
            (folder / 'src/nested').mkdir(parents=True)
            (folder / 'manifest.json').write_text('{"id":"minimap","api":1}')
            (folder / 'src/nested/module.lua').write_text('return {name = "example"}\n')
            package_mod(folder, root)
            content = (root / 'minimap.json').read_bytes()
            self.assertEqual(json.loads(content)['files'], {'nested.module': 'return {name = "example"}\n'})
            self.assertEqual((root / 'minimap.sha256').read_text().strip(), hashlib.sha256(content).hexdigest())

    def test_image_checksum_is_portable_and_has_no_absolute_path(self):
        with tempfile.TemporaryDirectory() as temporary:
            image = pathlib.Path(temporary) / 'Installer.dmg'
            image.write_bytes(b'package')
            checksum(image)
            expected = hashlib.sha256(b'package').hexdigest() + '  Installer.dmg\n'
            self.assertEqual(image.with_suffix('.dmg.sha256').read_text(), expected)


if __name__ == '__main__':
    unittest.main()
