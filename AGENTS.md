# Project guidelines

Use English for code, comments, documentation, and user interface text.
Use master as the primary branch. Keep repositories private.
Keep handwritten source files at or below 300 lines; split by responsibility.
Never commit user paths, saves, logs, machine state, credentials, or private test fixtures.
Use repository-relative paths and runtime user-directory discovery.
Keep engine access on the game thread and bound per-frame work.
Preserve ordinary game behavior and fail closed on unsupported game builds.
Test lifecycle changes through startup, world transitions, and shutdown.
Do not claim runtime verification from mocks or compilation alone.
