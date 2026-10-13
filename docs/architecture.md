# Architecture

The launcher starts the original game with its own library and inherited pipes.
The library validates the executable UUID before binding engine symbols. An
instance-specific engine tick wrapper runs Lua only on the game thread after
the original tick. Object references carry registry indices and serials; calls
reject destroyed objects. Parameter storage uses engine initialization and
cleanup, including strings, text, structs and output parameters.

The launcher exposes an owner-only Unix socket. The native runtime does not
listen on a network port. Packages are bundled, bounded and SHA-256 checked.
Catalogue state is written atomically. Disabling, removing and traveling trigger
cleanup callbacks; mod code cannot keep stale movement inputs held indefinitely.

A mod has an API-1 manifest and Lua modules under src. The runtime passes an
isolated module environment with settings, timers, lifecycle callbacks, shared
controls and weak object discovery. This is an interface boundary for trusted
bundled code, not a security sandbox for untrusted plugins. Native reflection
must only be used against a verified executable profile.

The Mods category extends the native Options screen and restores its original
content and action bindings when changing categories or closing. Native settings
widgets own interaction; the visible mod page samples changed values at 10 Hz.
Idle pages do not write settings. Text edits commit on focus loss or page exit.
Engine boolean writes use the property's byte mask; opaque action-binding values
use engine-owned struct initialization, copying and destruction. Array assignment
validates and constructs new storage before replacing the old value.

Rendering uses the game's own UMG widgets. Minimap observations are cached and
sampled separately from presentation. Discovery scans a bounded number of
registry slots each frame. Player input leases expire within two seconds and
stop during menus, loading or player loss. Autonomy is a separate consumer of
the same controls used by the MCP bridge.

Engine work is bounded where possible. Cold asset loading, UMG construction and
Unreal synchronous navigation can still exceed a frame budget. CPU timer
measurements are not GPU frame-time measurements or proof of universal smoothness.
