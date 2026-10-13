# Local trust boundary

The launcher accepts only same-user Unix-socket connections in a private data
directory. Any process running as that user can request supported game actions.
There is no remote listener, telemetry or AI provider key. Optional GitHub update
credentials live only in the login Keychain. They are sent only to the fixed
GitHub API repository and stripped from asset redirects.

Only bundled catalogue packages can be installed by the production host. Package
hashes detect corruption; they are not a substitute for trusting the release
publisher. Development builds deliberately include evaluation and must not be
distributed as production packages.

MCP clients should obtain the user's authorization for the world and actions to
perform. Timeouts do not imply that an action was not executed. Inspect state
before retrying. Keep saves, logs, personal fixtures, tokens and generated binary
outputs out of source control. Report issues privately through repository access.

Updates require an Ed25519-signed manifest pinned to the bundled public key,
plus an exact SHA-256 archive digest. Bounds, bundle identity, architecture,
minimum macOS version and all code signatures are checked before replacement.
Only stable semantic versions newer than the installed version are accepted.
The helper acquires the launch lock, waits for the launcher and game to exit,
and atomically exchanges complete bundles without elevation. It retains one
previous version for recovery. It never modifies the licensed game or save data.
The publisher's private signing key stays in Keychain on the release machine.
