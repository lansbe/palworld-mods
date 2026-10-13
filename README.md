# Palworld Mods

A native mod runtime and in-game **Mods** menu for Palworld on Apple silicon.
The menu, loader and launcher are original code. Lua 5.4 is bundled; there is no
external mod manager, Python service or package manager to run while playing.

## Install

1. Install the supported Mac App Store edition of Palworld.
2. Open the **Palworld Mods.dmg** disk image from the [latest release](https://github.com/lansbe/palworld-mods/releases/latest).
3. Drag **Palworld Mods** into **Applications**, then eject the disk image.
4. Close Palworld once, then open **Palworld Mods** from Applications.
5. In the game, open **Options → Mods**.

Mods appears as a category inside Palworld's native settings screen. The pause
menu also has a Mods shortcut. Mod settings use the game's own switches, choice
arrows, sliders and scrollable panel; there is no separate management window.

The installer includes Minimap and requires no Terminal commands or additional
downloads. **Palworld Mods.app** is a separate app; it does not replace the
licensed **Palworld.app**. Settings carry over from previous launcher versions.
**Options → Mods → Updates** controls app updates. Automatic updates are enabled
by default and can be disabled at any time; your choice survives relaunches.
Public releases require no GitHub account or token. If GitHub rate-limits an
anonymous check, the menu offers an optional connection using an existing GitHub
CLI login or a read-only token stored in Keychain. No credential is stored in settings
or logs.

The app checks in the background at launch when due, then at most every six
hours. Signed updates download without interrupting play and install after a
normal game exit. **Check for updates** and **Install update** also work with
automatic updates disabled. Installation completes before the next launch; the
running game is never forcibly restarted. Turning automatic updates off cancels
any pending download or installation. You can still replace the app manually
using a release disk image.

**Manage mods** installs or removes bundled mods immediately. An absent mod is
gray; select it to install. Select an installed mod on the Mods page to change
its settings or enable it. Minimap is installed by default. Autonomy starts only
when explicitly enabled through its **Running** setting.

Runtime upgrades require one game restart. Installing, removing, enabling and
configuring bundled mods does not. The original game app and saves are unchanged.
Launching the original App Store app directly starts the unmodified game.

Local builds are ad hoc signed, not notarized. Downloaded builds may require
approval in **System Settings → Privacy & Security → Open Anyway**, after a launch
attempt. Only approve a build you trust. Developer ID signing and notarization
are supported by the release builder; see [distribution](docs/distribution.md).

## Language

**Options → Mods → Language** defaults to **Automatic — game language**. All 17
Palworld locales are included, including both Spanish and Chinese variants.
Select a language to override it immediately, or choose Automatic to follow the
actual game language again. The choice survives relaunches and app updates.
It changes our menu, bundled mods, installer messages and MCP descriptions;
it does not change Palworld's own interface language.

The shared preference is stored locally in `preferences.json`. Before the first
game launch, the installer uses the Mac language; afterwards it uses the last
detected game language unless an override is selected. Protocol names, parsed
game IDs and technical diagnostics retain stable English identifiers.

Every feature must include all translations. See [localization](docs/localization.md)
for the catalogue format, API and mandatory validation rules.

## Compatibility

- Apple silicon, macOS 14 or later.
- App Store app 1.0.8, game build 102999.
- Supported executable UUID: `486483B8-7F7B-3787-8163-1D46C369C045`.

Unknown executable builds leave the runtime disabled. Do not substitute offsets
or force a mismatched profile after a game update. Multiplayer remains subject
to the host's normal replication, permissions and connection quality.

## Development

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
See [updates](docs/updates.md) for the release and validation workflow.

`python3 scripts/build.py --development` explicitly adds an evaluation command
for local development. The app packager always builds without that command;
the production host never exposes arbitrary evaluation or external packages.
With Options open in a development runtime, `tests/native_settings.lua` can be
evaluated through that development probe to verify real native control behavior.
It is not a standalone Lua test and does not run against a mocked engine.

## Local data and diagnostics

Settings, the owner-only control socket and bounded runtime logs live in the
user's Application Support/PalworldMods directory. Logs record command names,
request IDs, native errors and termination status, without command arguments.
Game-generated messages and crash reports may contain local player information.
Review these files before sharing them. Nothing is uploaded automatically.

The latest matching macOS crash report is collected when available, including on
the next launch if macOS writes it after the process exits. These records help
investigate failures; they do not prove a native crash has been fixed.

## Remove

Close the game and move **Palworld Mods** from Applications to the Trash. Launch
the original **Palworld** app to play without mods. Settings can be kept for later
use. Deleting the mod runtime does not delete game saves. An older launcher named
Palworld in the user Applications folder and its Desktop shortcut can also be
removed after verifying the new app; keep the original Mac App Store game.

See [architecture](docs/architecture.md), [validation](docs/validation.md),
[security](SECURITY.md) and [third-party notices](THIRD_PARTY_NOTICES.md).

## Contributing and license

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, checks and pull-request guidelines.
The original code is available under the [MIT license](LICENSE). Third-party
components keep their own licenses. This is an independent community project,
not an official Pocketpair product; Palworld and its game assets are not included.
