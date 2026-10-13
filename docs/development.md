# Development

[Back to the installation guide](../README.md)

Keep these repositories alongside one another:

```text
palworld-mods/
palworld-mod-minimap/
palworld-mod-autonomy/
palworld-mcp/
```

Install Xcode Command Line Tools, Python 3.12+ and Lua 5.4 for source validation.
Then run:

```sh
python3 scripts/verify.py
python3 -m unittest discover -s tests -p 'test_*.py'
lua tests/extensions.lua
lua tests/settings.lua
lua tests/localization.lua
lua tests/tree.lua
lua tests/updates.lua
python3 scripts/test_updates.py
python3 -m venv .venv
.venv/bin/python -m pip install --require-hashes -r scripts/requirements-packaging.txt
.venv/bin/python scripts/package_dmg.py
.venv/bin/python scripts/verify_package.py dist/palworld-mods-0.4.2-macos-arm64.dmg
```

The build downloads checksum-pinned Lua sources. `dist/Palworld Mods.app` contains
the runtime, native Swift launcher, original icon, notices and offline mod
catalogue. The `.dmg` contains the app and a shortcut to Applications. Packaging
tools run only during the build; no Python or packaging dependency ships with
the app. Game assets are resolved from the licensed game and are never packaged.

`src/native` provides checked Unreal reflection, weak handles, native input and
bounded transport. `src/runtime` owns the menu, lifecycle and shared game API.
`src/launcher` manages launch, local IPC, installation state and diagnostics.
`src/update` contains signed-package validation and atomic replacement;
`src/update-installer` is an unprivileged helper that exits after installation.
See [updates](updates.md) for the release and validation workflow.

`python3 scripts/build.py --development` explicitly adds an evaluation command
for local development. The app packager always builds without that command;
the production host never exposes arbitrary evaluation or external packages.
With Options open in a development runtime, `tests/native_settings.lua` can be
evaluated through that development probe to verify real native control behavior.
It is not a standalone Lua test and does not run against a mocked engine.


Read [CONTRIBUTING.md](../CONTRIBUTING.md) before submitting a change.
