# macOS distribution

The release format is a compressed, read-only disk image with two visible items:
**Palworld Mods.app** and **Applications**. Users drag the app to the folder,
eject the image and launch the installed app. The disk-image installation needs no shell script, background service or
administrator daemon. App updates use a bundled, short-lived unprivileged helper.

The app name deliberately differs from the licensed game. Finder handles copying
and replacement through the usual macOS dialogs. Mod settings remain in the same
Application Support directory, independently of where the app is installed.

## Build a local installer

Place the Minimap and Autonomy repositories alongside this repository. Install
Xcode Command Line Tools and Python 3.12 or newer, then run:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install --require-hashes -r scripts/requirements-packaging.txt
.venv/bin/python scripts/package_dmg.py
.venv/bin/python scripts/verify_package.py dist/palworld-mods-0.4.0-macos-arm64.dmg
```

`VERSION` controls the app metadata and image filename. `scripts/assets.swift`
draws the icon and Retina installer background from editable geometry.
`package_app.py` builds in a temporary directory before replacing its previous
output. `package_dmg.py` creates Finder layout metadata without opening Finder or
requiring Accessibility/Automation permissions. Dependencies are hash-pinned
and are used only on the build machine.

The verifier mounts the finished image read-only, verifies its checksum, app
name and identifier, both native code signatures, architecture, catalogue hashes,
Finder layout and Applications link, then unmounts it.

## Developer ID and notarization

An ad hoc signature validates local integrity but does not establish an Apple
distribution identity. Apple Development and Apple Distribution certificates do
not replace a **Developer ID Application** certificate for this distribution.
No Gatekeeper, quarantine or System Integrity Protection setting is bypassed.

With a Developer ID certificate and an existing notarytool Keychain profile:

```sh
.venv/bin/python scripts/package_dmg.py \
  --sign-identity 'Developer ID Application: YOUR SIGNING IDENTITY' \
  --notary-profile 'YOUR KEYCHAIN PROFILE'
```

The builder signs the library and app explicitly, enables hardened runtime,
requests secure timestamps, notarizes and staples the app, creates the image,
then signs, notarizes and staples the image. Credentials remain in Keychain and
are never included in the repository or distribution. A successful local build
does not prove notarization or a successful first download on another Mac.

Before publishing, verify with `spctl --assess --type execute --verbose` on the
app and test a quarantined download on a separate supported Mac, including
startup, Options → Mods, return to title and shutdown. Publish the `.dmg` and
its matching `.sha256` file together. Do not replace a release asset silently.

See Apple's [notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
and [distribution signing guide](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac/).

Build and publish the signed update assets alongside each disk image. See
[the update release workflow](updates.md).
