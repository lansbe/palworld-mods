# Validation record

Verified locally on Apple silicon with the supported App Store executable.
This record describes observed results, not guarantees for every game session.

## Automated checks

- Strict native C++/Objective-C and Swift compilation.
- Lua source syntax, source file limits and privacy-pattern checks.
- Mod installation rollback, disable, travel cleanup and shutdown.
- Minimap coordinate rotation, map-edge clipping, route clipping, incremental
  boundary calibration and setting bounds.
- Autonomy goal parsing, lifetime capture quotas, confirmation after actor
  removal, menu pause, health/reserve rules, camera alignment, route reuse,
  unreachable pickups and bounded retreat/return retries.
- Real MCP stdio initialization, tools, invalid requests, argument validation
  and disconnected transport behavior.

## Game checks

- Independent native runtime attaches without an external loader.
- Local temporary world loaded through native menu buttons.
- Native Mods and Minimap settings inspected visually in the game.
- Catalogue uninstall/reinstall and enable/disable confirmed while in a world.
- Settings persisted by the standalone Swift launcher; arbitrary evaluation
  rejected by its production command interface.
- Bounded walking input moved the player; jump and stop inputs accepted.
- Inventory and incremental nearby Pal/resource observations returned native data.
- Return-to-title and normal game shutdown completed with exit status zero.
- Autonomy installed without starting, reported stopped, and was removed cleanly.

## Installer checks (0.2.0)

- Compressed read-only DMG verified after mounting, including its checksum,
  native signatures, architecture, complete catalogue and Applications link.
- Actual Finder layout inspected on a Retina display after correcting scaling.
- Launching from the mounted image showed the native install guidance; its
  Show Installer button returned to Finder without launching the game.
- Finder copied the app to Applications; the installed copy matched the image.
- With the image ejected, the installed app reached the title screen, connected
  its native runtime, loaded enabled Minimap and quit with a normal exit.
- The licensed game executable fingerprint was unchanged by installation.
- Source/privacy checks and four packaging contract tests passed.

The UI automation service could not perform a native drag gesture. The copy was
tested through Finder's Copy/Paste into the same Applications shortcut instead.
Developer ID signing and notarization could not be tested because no Developer
ID certificate was available. The locally signed app passed signature integrity
checks and launched locally; Gatekeeper's distribution assessment rejected it
as expected for this ad hoc build. Another Mac's first-download experience is
not verified.

## Native settings regression (0.2.1)

- Replaced the separate full-screen mod canvas with the native Options sidebar
  and settings panel; inspected switches, selectors, sliders and text fields.
- Real native ON/OFF clicks, choice arrows and slider increments changed only
  their associated mod settings. Unmodified off-step saved values stayed intact.
- Native string arrays round-tripped; invalid and sparse assignments failed
  without replacing the previous values. Empty assignments cleared the array.
- Native text edits persisted without starting Autonomy. Mod uninstall/reinstall
  preserved Minimap settings, and absent catalogue entries were dimmed.
- Switching to Graphics restored the game's original panel. Closing Mods removed
  its panel; the pause-menu shortcut opened the native settings while in a world.
- Local world entry, return to title with automatic save and normal shutdown
  completed without runtime errors in the tested development session.
- The installed 0.2.1 production app repeated title/world menu navigation,
  category switching, closing back to playable state and return to title. Its
  diagnostics were empty and shutdown exited normally. Arbitrary evaluation was
  rejected. The original game executable fingerprint remained unchanged.
- The 0.2.1 DMG passed mounted content, signature, catalogue and checksum checks.

Automated settings tests cover preservation, numeric steps, idle writes and text
commit. Real native regression checks are in `tests/native_settings.lua` and need
the supported game, an open Options screen and a development runtime. A physical
controller navigation pass and all mouse gestures have not been verified.

## Runtime limits

A startup hang occurred when requesting exclusive fullscreen before the engine
initialized. The launcher now starts windowed and applies saved fullscreen from
the game thread after initialization. It does not repeatedly override later user
changes. A short initial window transition can still be visible.

Cold minimap construction measured up to approximately 38 ms in the integration
run. Steady work was much smaller, but this is not a GPU or full-session smoothness
benchmark. Multiplayer guild visibility, mounted/dungeon transitions and complete
autonomous capture/gather sessions require additional scenario validation on the
new runtime. The stable release does not include a room-and-wall dungeon plan.

No native VectorVM crash root cause is claimed. Bounded logs and available macOS
crash reports are retained locally to support a future diagnosis.
