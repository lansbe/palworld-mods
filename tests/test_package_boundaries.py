"""Exercise catalogue input/output boundaries with synthetic repositories."""
import hashlib
import json
import os
import pathlib
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'scripts'))
from localization import LANGUAGES
from package_app import package_mod
from package_io import MAX_BYTES, MAX_ENTRIES


class PackageBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        self.repo, self.output = self.root / 'mod', self.root / 'Catalog'
        self.output.mkdir()
        (self.repo / 'src/nested').mkdir(parents=True)
        (self.repo / 'manifest.json').write_text('{"id":"minimap","api":1}')
        (self.repo / 'LICENSE').write_text('MIT License\n')
        (self.repo / 'src/nested/module.lua').write_text('return {value="日本語"}\n')
        self.outside = self.root / 'outside.txt'
        self.outside.write_text('SYNTHETIC_PRIVATE_FIXTURE')

    def package(self, identifier='minimap'):
        package_mod(self.repo, self.output, identifier)

    def add_locales(self):
        folder = self.repo / 'locales'
        folder.mkdir()
        for language in LANGUAGES:
            (folder / (language + '.json')).write_text('{"hello":"Hello {name}"}')
        return folder

    def test_regular_files_and_all_locales_remain_usable(self):
        self.add_locales()
        for identifier in ['minimap', 'autonomy']:
            with self.subTest(identifier=identifier):
                (self.repo / 'manifest.json').write_text(json.dumps({'id': identifier, 'api': 1}))
                self.package(identifier)
                data = (self.output / (identifier + '.json')).read_bytes()
                package = json.loads(data)
                self.assertEqual(package['files'], {'nested.module': 'return {value="日本語"}\n'})
                self.assertEqual(len(package['translations']), 17)
                self.assertEqual(package['licenseText'], 'MIT License\n')
                self.assertEqual((self.output / (identifier + '.sha256')).read_text().strip(),
                                 hashlib.sha256(data).hexdigest())
                self.assertEqual((self.output / (identifier + '.json')).stat().st_mode & 0o777, 0o644)

    def test_manifest_ids_cannot_choose_output_paths(self):
        for value in ['../escaped', str(self.root / 'absolute'), 'a/b', 'a\\b', '..', '.',
                      '%2e%2e%2fescaped', 'mini∕map', 'mini／map', 'autonomy', None, ['minimap']]:
            with self.subTest(value=value):
                (self.repo / 'manifest.json').write_text(json.dumps({'id': value, 'api': 1}))
                with self.assertRaises(ValueError):
                    self.package()
                self.assertEqual(list(self.output.iterdir()), [])
                self.assertFalse((self.root / 'escaped.json').exists())
        (self.repo / 'manifest.json').write_text('{"id":"../escaped"}')
        with self.assertRaises(ValueError):
            self.package('../escaped')

    def test_manifest_license_lua_and_locale_file_links_are_rejected(self):
        self.add_locales()
        for relative in ['manifest.json', 'LICENSE', 'src/nested/module.lua', 'locales/fr.json']:
            with self.subTest(relative=relative):
                path = self.repo / relative
                original = path.read_bytes()
                path.unlink()
                path.symlink_to(self.outside)
                try:
                    with self.assertRaises((OSError, ValueError)):
                        self.package()
                    self.assertEqual(list(self.output.iterdir()), [])
                    self.assertEqual(self.outside.read_text(), 'SYNTHETIC_PRIVATE_FIXTURE')
                finally:
                    path.unlink()
                    path.write_bytes(original)

    def test_directory_links_including_checkout_root_are_rejected(self):
        self.add_locales()
        for relative in ['src', 'src/nested', 'locales']:
            with self.subTest(relative=relative):
                path = self.repo / relative
                saved = path.with_name(path.name + '-saved')
                path.rename(saved)
                path.symlink_to(saved, target_is_directory=True)
                try:
                    with self.assertRaises((OSError, ValueError)):
                        self.package()
                    self.assertEqual(list(self.output.iterdir()), [])
                finally:
                    path.unlink()
                    saved.rename(path)
        alias = self.root / 'mod-link'
        alias.symlink_to(self.repo, target_is_directory=True)
        with self.assertRaises(OSError):
            package_mod(alias, self.output, 'minimap')

    def test_file_replaced_by_link_at_open_is_rejected(self):
        original = os.open
        changed = False

        def swap(path, flags, *args, **kwargs):
            nonlocal changed
            if path == 'module.lua' and not changed:
                changed = True
                source = self.repo / 'src/nested/module.lua'
                source.unlink()
                source.symlink_to(self.outside)
            return original(path, flags, *args, **kwargs)

        with patch('package_io.os.open', side_effect=swap), self.assertRaises(OSError):
            self.package()
        self.assertTrue(changed)
        self.assertEqual(list(self.output.iterdir()), [])

    def test_link_output_and_directory_link_are_rejected_before_writes(self):
        for name in ['minimap.json', 'minimap.sha256']:
            with self.subTest(name=name):
                target = self.output / name
                target.symlink_to(self.outside)
                try:
                    with self.assertRaises(ValueError):
                        self.package()
                    self.assertEqual(self.outside.read_text(), 'SYNTHETIC_PRIVATE_FIXTURE')
                    self.assertEqual(list(self.output.iterdir()), [target])
                finally:
                    target.unlink()
        alias = self.root / 'catalog-link'
        alias.symlink_to(self.output, target_is_directory=True)
        with self.assertRaises(OSError):
            package_mod(self.repo, alias, 'minimap')

    def test_atomic_replace_does_not_truncate_existing_hardlink_targets(self):
        os.link(self.outside, self.output / 'minimap.json')
        self.package()
        self.assertEqual(self.outside.read_text(), 'SYNTHETIC_PRIVATE_FIXTURE')
        self.assertNotEqual((self.output / 'minimap.json').stat().st_ino, self.outside.stat().st_ino)

    def test_input_hardlink_cannot_copy_an_external_file(self):
        path = self.repo / 'src/nested/module.lua'
        path.unlink()
        os.link(self.outside, path)
        with self.assertRaises(ValueError):
            self.package()
        self.assertEqual(self.outside.read_text(), 'SYNTHETIC_PRIVATE_FIXTURE')
        self.assertEqual(list(self.output.iterdir()), [])

    def test_special_files_and_budgets_fail_without_output(self):
        path = self.repo / 'src/nested/module.lua'
        path.unlink()
        os.mkfifo(path)
        with self.assertRaises(ValueError):
            self.package()
        path.unlink()
        path.write_text('x' * (MAX_BYTES + 1))
        with self.assertRaises(ValueError):
            self.package()
        path.write_text('return {}')
        for index in range(MAX_ENTRIES):
            (self.repo / 'src' / ('file' + str(index))).touch()
        with self.assertRaises(ValueError):
            self.package()
        self.assertEqual(list(self.output.iterdir()), [])


if __name__ == '__main__':
    unittest.main()
