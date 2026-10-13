# Project guidelines

Use English for identifiers, code comments and documentation. Store translated user-facing text in locale catalogues.
Use master as the primary branch. Keep repositories private.
Keep handwritten source files at or below 300 lines; split by responsibility.
Never commit user paths, saves, logs, machine state, credentials, or private test fixtures.
Use repository-relative paths and runtime user-directory discovery.
Keep engine access on the game thread and bound per-frame work.
Preserve ordinary game behavior and fail closed on unsupported game builds.
Test lifecycle changes through startup, world transitions, and shutdown.
Do not claim runtime verification from mocks or compilation alone.

## Mandatory localization

Every new or changed feature must ship complete translations for all 17 supported
Palworld locales. This includes labels, options, hints, notifications and user-facing
status/error messages. Use stable catalogue keys and named placeholders; never
concatenate translated sentence fragments or store translated option labels as values.
Keep protocol identifiers, parsed game IDs and technical diagnostics stable in English.
Follow the shared in-game language preference: auto detects the actual game language;
a manual override persists across launches without changing Palworld's own language.
Do not add per-mod language settings. Preserve English fallback for unknown locales.
Run scripts/check_localization.py and the relevant behavior tests before delivery.
Check live language changes and representative long, Cyrillic and Asian text in game.
Missing languages, missing keys, empty values or mismatched placeholders block release.
