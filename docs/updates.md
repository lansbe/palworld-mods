# App updates

The native **Mods → Updates** page owns the automatic-update switch, check,
install and GitHub connection actions. The switch defaults to enabled and lives
in the private `updates.json` preference file. Language continues to use the
shared game-language preference; every label and status has all 17 translations.
No polling, archive work, disk access or network request runs on the game thread.
Status changes alone refresh the Updates page. Other game pages are unchanged.

## Delivery and trust

The source is the public `lansbe/palworld-mods` GitHub repository. Checks and
downloads work without an account. After an authentication or rate-limit failure,
Connect GitHub optionally reuses a local CLI login or accepts a read-only token in
a native secure-field dialog. Invalid optional credentials fall back to anonymous
access. Disconnect cancels queued work without making public checks unavailable.
A selected CLI provider is remembered without copying its token. Its credential
lookup has a three-second limit. Keychain access runs on a separate utility queue;
legacy ACL prompts are disabled outside an explicit Connect action. Credential
loading never delays game startup or blocks the control socket.
The shipped app has no CLI dependency. Disconnect removes its Keychain entry and
cancels pending work. Ad hoc builds may require reconnection after code-signature
changes; Developer ID releases preserve their stable signing identity.

The updater enumerates stable releases and compares numeric semantic versions.
It does not trust GitHub's latest flag or creation-date order. A newer release
without complete signed assets is reported as an error, not silently installed.
Checks use an ephemeral URL session, strict byte/time limits and no disk cache.
Authorization never follows an asset redirect. Only approved HTTPS GitHub asset
hosts can receive redirected downloads.

An Ed25519 signature authenticates the exact manifest bytes. The pinned public
key ships in `UpdateTrust.swift`; its private half exists only in the release
machine's Keychain. The signed manifest binds version, bundle identity, platform,
archive name, size and SHA-256 hash. Extraction rejects unsafe archive paths.
The complete app, native runtime and update helper must have valid code signatures
and the supported architecture. Release authentication does not replace Apple
Developer ID signing or notarization; ad hoc builds remain local-trust builds.

## Installation lifecycle

An automatic check is due after six hours; a lightweight hourly timer checks that
deadline. Failed or unfinished updates are retried on the next launch. Manual
checks bypass the interval. Disabling automatic updates cancels in-flight work
and queued installation, while manual check/install remain available.

A downloaded update is staged in a private per-user directory. Nothing replaces
the running runtime. After a normal game exit, the launcher starts a copied helper
and exits. The helper waits for its parent, takes the same launch lock and confirms
that Palworld is closed. It re-verifies and re-extracts the signed archive, copies
a complete candidate beside the installed app and atomically exchanges the bundles.
Validation failure restores the original bundle. One hidden previous app remains
beside the installation for recovery. A failed install is shown on the next launch.
Crash exits never trigger installation. No force quit, administrator service,
privilege escalation, quarantine removal or game/save modification is performed.

## Publish a release

1. Run source, localization and updater behavior checks.
2. Increment `VERSION` and build/verify the disk image as documented in distribution.
3. Run `python3 scripts/package_update.py` against that exact verified app.
4. Upload the `.dmg`, `.dmg.sha256`, versioned `.zip`, `.zip.sha256`,
   `palworld-mods-update.json` and `palworld-mods-update.sig` to the same stable tag.
5. Use `<version> - <short English release name>` as the title, and `v<version>`
   as the tag. Prepare assets in a draft release, then publish them together.
6. Run `python3 scripts/test_public_updates.py` to verify the published download
   without credentials, then check installation in a disposable app copy.

A release machine initializes its signing key once with:

```sh
xcrun swift scripts/update_signer.swift initialize src/update/UpdateTrust.swift
```

The command refuses to replace an existing public key. Do not generate a new key
for ordinary releases: installed apps trust the existing one. Back up the signing
identity securely outside the repository. Key rotation needs a separately reviewed
migration signed by the existing key. Never commit a token, signing key or fixture
containing user data. Protocol and diagnostic identifiers remain in English.

## Validation

`python3 scripts/test_updates.py` covers signature tampering, incorrect identity,
unsafe filenames, version ordering, release selection, platform/size bounds and
persistent opt-out. `lua tests/updates.lua` covers native menu action availability
and busy-state behavior. After packaging, run `python3 scripts/test_update_installation.py` to exercise
replacement of a disposable signed bundle, including metadata cache invalidation,
backup preservation and corrupt archive rejection. Still inspect the live localized
game menu and the helper's behavior while the real game is running.

The protocol uses GitHub's [release asset API](https://docs.github.com/en/rest/releases/assets)
and Apple's [Curve25519 signature verification](https://developer.apple.com/documentation/cryptokit/curve25519/signing/publickey/isvalidsignature(_:for:)).
