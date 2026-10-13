# Contributing

Bug fixes, documentation, translations and performance improvements are welcome.
For a substantial change, open an issue first to discuss scope and compatibility.
Use the [issue tracker](https://github.com/lansbe/palworld-mods/issues) for ordinary bugs
and feature requests; see [security reporting](SECURITY.md) for vulnerabilities.

## Development setup

Fork the repository, clone your fork and create a focused branch from `master`.
Read [README.md](README.md) and [AGENTS.md](AGENTS.md) for the current boundaries.

Use Python 3.12+ and Lua 5.4. Building the native runtime or MCP bridge also
requires macOS and Xcode Command Line Tools. Running integration scenarios needs
the supported, separately licensed Mac App Store game; ordinary checks need no
world saves, account credentials or game assets.

For app packaging, clone `palworld-mod-minimap` and `palworld-mod-autonomy`
beside this repository. See [distribution](docs/distribution.md) for the virtual
environment, installer build and signature checks. Release signing credentials
are not required to build or contribute; do not request or commit them.

Run from the repository root:

```sh
python3 scripts/verify.py
python3 -m unittest discover -s tests -p 'test_*.py'
lua tests/extensions.lua
lua tests/settings.lua
lua tests/localization.lua
lua tests/tree.lua
lua tests/updates.lua
python3 scripts/test_updates.py
python3 scripts/build.py
```

## Implementation rules

- Use English for code, comments and documentation. Keep handwritten source files
  at or below 300 lines and split modules by responsibility.
- Put every user-facing label, hint, status and error in locale catalogues. Supply
  all 17 languages and preserve the shared automatic/manual language preference.
- Keep engine access on the game thread and bound per-frame work. Avoid blocking
  disk/network operations, repeated full scans and unbounded caches in gameplay.
- Preserve game behavior and fail closed for unsupported builds. Do not force
  offsets or ship arbitrary evaluation in production packages.
- Never commit saves, logs, player identifiers, local paths, credentials, signing
  keys, compiled outputs or copyrighted game assets. Use synthetic test fixtures.
- Include only code you have the right to contribute. Preserve third-party notices
  and explain new dependencies, their license and their runtime/build purpose.

## Verification and pull requests

Target `master`. Explain the problem, resulting behavior and relevant validation.
Add regression tests for changed behavior where useful; documentation-only edits
need documentation/link checks, not a complete gameplay run.

For native UI changes, inspect the actual in-game menu, language changes and
representative long, Cyrillic and Asian labels. For lifecycle changes, check startup,
world transitions and normal shutdown. For performance changes, compare the same
scenario and settings before/after and distinguish CPU timings from GPU measurements.
Describe unavailable checks honestly; compilation or mocks do not prove gameplay.

Bug reports should include the app/mod version, macOS version, game build, minimal
steps and expected/actual behavior. Review diagnostic excerpts and screenshots for
personal data before attaching them. Do not upload complete saves or raw crash dumps.

Maintainers own release tags, signing and publication. Release titles use
`<version> - <short English release name>` with an ASCII hyphen; tags use `v<version>`.
Version changes should be coordinated with maintainers instead of added to every PR.

## License

Contributions are accepted under the repository's [MIT license](LICENSE).
By submitting code, you agree that it may be distributed under that license.
Palworld, its trademarks and game assets remain the property of their owners;
this independent project does not grant rights to redistribute them.
