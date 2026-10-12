# Palworld Mods

A native mod runtime and in-game **Mods** menu for Palworld on Apple silicon.
The menu, loader and launcher are original code. Lua 5.4 is bundled; there is no
external mod manager, Python service or package manager to run while playing.

## Install

1. Install the supported Mac App Store edition of Palworld.
2. Download and extract the private release archive.
3. Close Palworld once, then double-click **Install.command**.
4. Open **Palworld** from the Desktop shortcut. Open **Options → Mods**.

**Manage mods** installs or removes bundled mods immediately. An absent mod is
gray; select it to install. Select an installed mod on the Mods page to change
its settings or enable it. Minimap is installed by default. Autonomy starts only
when explicitly enabled through its **Running** setting.

Runtime upgrades require one game restart. Installing, removing, enabling and
configuring bundled mods does not. The original game app and saves are unchanged.
Launching the original App Store app directly starts the unmodified game.

The current app is locally signed, not notarized. Downloaded builds may require
macOS approval. Developer ID signing is required for a notarized distribution.

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
lua tests/extensions.lua
python3 scripts/package_app.py
```

The build downloads checksum-pinned Lua sources. `dist/Palworld.app` contains the
runtime, native Swift launcher, notices and offline mod catalogue. Game assets
are resolved from the licensed game and are never packaged.

`src/native` provides checked Unreal reflection, weak handles, native input and
bounded transport. `src/runtime` owns the menu, lifecycle and shared game API.
`src/launcher` manages launch, local IPC, installation state and diagnostics.

`python3 scripts/build.py --development` explicitly adds an evaluation command
for local development. The app packager always builds without that command;
the production host never exposes arbitrary evaluation or external packages.

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

Close the game, remove the installed launcher and its Desktop shortcut, then
launch the original app from Applications. Settings can be kept for later use.
Deleting the mod runtime does not delete game saves.

See [architecture](docs/architecture.md), [validation](docs/validation.md),
[security](SECURITY.md) and [third-party notices](THIRD_PARTY_NOTICES.md).
