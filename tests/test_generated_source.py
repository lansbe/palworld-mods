"""Generated catalogue bytes must remain data through both compilers."""
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'scripts'))
import localization
from generated_source import cpp_module


class GeneratedSourceTests(unittest.TestCase):
    def test_catalogue_round_trips_without_executing_translation_text(self):
        values = [
            "before]==] .. (function() _G.security_payload_ran=true; return '' end)() .. [==[after {name}",
            ']] ]=] ]==] ]===] --[[ )PAL_LUA )PAL_LUA1',
            'Quotes: " and \\; newline\ncarriage\r 日本語 Привет Français {name}',
            ')PAL_LUA',
            ')PAL_LUA1',
        ]
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            (root / 'locales').mkdir()
            messages = {f'key{i}': value for i, value in enumerate(values)}
            messages[values[1]] = 'A key is also data'
            languages = [{'id': 'en', 'name': values[0]}]
            for language in localization.LANGUAGES:
                (root / 'locales' / (language + '.json')).write_text(json.dumps(messages), encoding='utf-8')
            (root / 'locales/languages.json').write_text(json.dumps(languages), encoding='utf-8')
            with patch.object(localization, 'ROOT', root):
                module = localization.embedded_module()
            result = self.run_lua(module)
            self.assertEqual(json.loads(result), {'languages': languages,
                             'messages': {language: messages for language in localization.LANGUAGES}})
            # Compile the same source through the native header boundary too.
            name = 'i18n.catalog"\n日本語'
            header = ('#include <iostream>\nstruct Module {const char* name; const char* source;};\n'
                      'const Module module = ' + cpp_module(name, module) + ';\n'
                      'int main(){std::cout << module.source;std::cerr << module.name;}\n')
            source, binary = root / 'embedded.cpp', root / 'embedded-check'
            source.write_text(header, encoding='utf-8')
            subprocess.run(['xcrun', 'clang++', '-std=c++20', '-Wall', '-Wextra', '-Werror',
                            str(source), '-o', str(binary)], check=True)
            compiled = subprocess.run([str(binary)], capture_output=True, check=True)
            self.assertEqual(compiled.stdout, module.encode('utf-8'))
            self.assertEqual(compiled.stderr, name.encode('utf-8'))
            self.assertEqual(self.run_lua(compiled.stdout.decode('utf-8')), result)

    def run_lua(self, module):
        harness = ('Engine={json_decode=function(value) return value end}\n'
                   'local value=(function() ' + module + ' end)()\n'
                   'assert(security_payload_ran==nil,"Translation became executable")\n'
                   'io.write(value)\n')
        return subprocess.run([os.environ.get('LUA_TEST_BINARY', 'lua'), '-'], input=harness.encode('utf-8'),
                              capture_output=True, check=True).stdout

    def test_core_copy_contains_only_validated_catalogues(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            with patch.object(localization, 'ROOT', localization.ROOT):
                localization.copy_catalogues(root / 'Locales')
            copied = root / 'Locales'
            self.assertEqual({p.stem for p in copied.iterdir()}, set(localization.LANGUAGES) | {'languages'})
            for language, messages in localization.load_catalogues().items():
                self.assertEqual(json.loads((copied / (language + '.json')).read_text()), messages)


if __name__ == '__main__':
    unittest.main()
