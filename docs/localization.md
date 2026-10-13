# Localization contract

Localization is mandatory for every user-facing feature in all four repositories.
Use English identifiers, comments and documentation, and translate presentation
strings in each repository's `locales/<tag>.json` files. Do not duplicate the
language preference or add a language setting to an individual mod.

## Supported locales

The [official Palworld language list](https://store.steampowered.com/app/1623730/Palworld/)
is represented by these 17 canonical tags:

`en`, `fr`, `de`, `es`, `es-419`, `it`, `pt-BR`, `pl`, `ru`, `tr`, `id`, `vi`,
`th`, `ja`, `ko`, `zh-Hans`, `zh-Hant`.

Each catalogue must contain exactly the English key set, nonempty values and the
same named placeholders. Duplicate keys are errors. Regional variants normalize
to a supported tag; unknown locales fall back to English. Keep native language
names in the language selector so users can recover from an accidental selection.

## Shared preference and lifecycle

The launcher owns `Application Support/PalworldMods/preferences.json`, created at
runtime outside the repositories. `language` is `auto` by default or a canonical
tag; `game_language` remembers the last actual engine language. Writes are atomic
and restricted to the current user. Invalid stored choices fall back to automatic.

The runtime reads `KismetInternationalizationLibrary.GetCurrentLanguage` once per
second on the game thread. A changed language increments a revision, translates
the open native menu and preserves its scroll offset. No file I/O or network
translation runs on a rendering path. Manual selection never changes the game's
own language and stays selected when the game language changes.

The launcher persists a requested selection before applying it. The MCP process
reads the same preference and refreshes descriptions when its client next requests
the tool list. Before the first engine detection, launch/install messages use the
Mac's preferred language; subsequent launches use the last detected game language.

## Mod API

The packager embeds each mod's catalogues in `package.translations`. The runtime
registers them under the mod ID, including uninstalled catalogue entries. The
host verifies the containing package's checksum before use.

```lua
-- A settings schema stores keys; values remain language-independent.
{key='shape', label='settings.shape', options={'square','round'},
 optionKeys={'shape.square','shape.round'}}

-- A dynamic message uses a whole sentence and named values.
api.translate('status.captured', {name=targetName, count=captureCount})
```

`hint` is also a catalogue key. The runtime creates translated copies of schemas
for native controls and MCP; it never mutates the original schema or raw option
IDs. Dynamic controller states store a key and arguments and render on read, so
switching languages does not restart actions or leave old translated events.
Missing individual translations use the English string as a runtime fallback;
the build checks still reject incomplete shipped catalogues.

## Required checks

Run `python3 scripts/check_localization.py` in every affected repository. CI also
runs it through `scripts/verify.py`. It rejects missing locales, mismatched keys,
empty strings, duplicate keys, placeholder differences and known unkeyed UI
declarations. Static checks are a guard, not a replacement for reviewing new UI.

Test automatic detection, a manual override, return to automatic, persistence
after relaunch and changing languages while a menu is open. Inspect long text,
Cyrillic and Asian scripts in the real native controls. Preserve game/mod values
through these transitions. Unit tests cover fallback, normalization, literal
placeholder values and translated schema copies.

Protocol names, parsed Pal/material IDs and raw technical diagnostics remain
stable in English. Do not translate an identifier that another component parses.
Expose a localized status message alongside detailed diagnostics where needed.
