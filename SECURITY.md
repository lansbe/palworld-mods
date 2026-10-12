# Local trust boundary

The launcher accepts only same-user Unix-socket connections in a private data
directory. Any process running as that user can request supported game actions.
There is no remote listener, telemetry, credential storage or AI provider key.

Only bundled catalogue packages can be installed by the production host. Package
hashes detect corruption; they are not a substitute for trusting the release
publisher. Development builds deliberately include evaluation and must not be
distributed as production packages.

MCP clients should obtain the user's authorization for the world and actions to
perform. Timeouts do not imply that an action was not executed. Inspect state
before retrying. Keep saves, logs, personal fixtures, tokens and generated binary
outputs out of source control. Report issues privately through repository access.
