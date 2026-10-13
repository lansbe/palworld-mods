import Foundation
import CryptoKit

func rejects(_ body: () throws -> Void) {
    do { try body(); fatalError("Expected rejection") } catch {}
}
let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).resolvingSymlinksInPath()
try UpdateFiles.directory(root)
defer { try? FileManager.default.removeItem(at: root) }
assert(ReleaseVersion("0.10.0")! > ReleaseVersion("0.9.9")!)
assert(ReleaseVersion("2.0.0")! > ReleaseVersion("1.99.99")!)
for value in ["v1.0.0", "1.0", "1.0.0-beta", "01.0.0", "1.-1.0", "1.0.０", "1.0.0/../"] {
    assert(ReleaseVersion(value) == nil)
}
let key = Curve25519.Signing.PrivateKey()
let endpoint = URL(string: "https://api.github.com/repos/lansbe/palworld-mods/releases")!
assert(UpdateDownload.request(endpoint, token: nil, binary: false).value(forHTTPHeaderField: "Authorization") == nil)
assert(UpdateDownload.request(endpoint, token: "test-token", binary: true).value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
let bytes = Data("signed update test".utf8)
let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
var document: [String: Any] = ["schema": 1, "version": "1.2.3", "bundleIdentifier": "org.palworldmods.launcher",
    "minimumSystemVersion": "14.0.0", "archive": "palworld-mods-1.2.3-macos-arm64.zip", "sha256": digest, "size": bytes.count]
func verify(_ object: [String: Any]) throws -> UpdateManifest {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    return try UpdateManifest.verified(data, signature: key.signature(for: data), publicKey: key.publicKey.rawRepresentation)
}
let valid = try verify(document)
let archive = root.appendingPathComponent("archive.zip")
try bytes.write(to: archive); try valid.verifyArchive(archive)
try Data("corrupt update".utf8).write(to: archive)
rejects { try valid.verifyArchive(archive) }
let encoded = try JSONSerialization.data(withJSONObject: document)
let signature = try key.signature(for: encoded)
rejects { _ = try UpdateManifest.verified(encoded + Data([0]), signature: signature, publicKey: key.publicKey.rawRepresentation) }
rejects { _ = try UpdateManifest.verified(encoded, signature: signature) }
for (field, value) in [("archive", "../Application.zip"), ("bundleIdentifier", "com.pocketpair.palworld.mac"),
                       ("version", "1.0.0-beta"), ("minimumSystemVersion", "999.0.0"), ("sha256", "wrong")] {
    var invalid = document; invalid[field] = value
    rejects { _ = try verify(invalid) }
}
for size in [0, -1, 67_108_865] {
    var invalid = document; invalid["size"] = size
    rejects { _ = try verify(invalid) }
}
let store = try UpdateStore(root: root)
assert(store.preferences.automatic, "Automatic updates must default to enabled")
var preference = store.preferences; preference.automatic = false
try store.save(preference)
let optedOut = try UpdateStore(root: root)
assert(optedOut.preferences.automatic == false, "Opt-out must survive relaunch")
preference.automatic = true; try store.save(preference)
let optedIn = try UpdateStore(root: root)
assert(optedIn.preferences.automatic, "Re-enabling must survive relaunch")
preference.credentialSource = "github-cli"; try store.save(preference)
let connected = try UpdateStore(root: root)
assert(connected.preferences.credentialSource == "github-cli", "Provider selection must survive relaunch")
try Data(#"{"automatic":false}"#.utf8).write(to: store.preferencesURL)
let migrated = try UpdateStore(root: root)
assert(!migrated.preferences.automatic && migrated.preferences.credentialSource == nil,
       "Existing opt-out must survive the credential-provider migration")
try store.save(preference)
let mode = try FileManager.default.attributesOfItem(atPath: store.preferencesURL.path)[.posixPermissions] as? Int
assert(mode == 0o600)
let fixture = #"[{"tag_name":"v0.9.0","draft":false,"prerelease":false,"assets":[]},{"tag_name":"v0.10.0","draft":false,"prerelease":false,"assets":[]},{"tag_name":"v9.0.0","draft":true,"prerelease":false,"assets":[]},{"tag_name":"v8.0.0","draft":false,"prerelease":true,"assets":[]}]"#
let releases = try JSONDecoder().decode([GitHubUpdateSource.Release].self, from: Data(fixture.utf8))
assert(GitHubUpdateSource.newest(releases, after: ReleaseVersion("0.8.0")!)?.tag_name == "v0.10.0")
assert(GitHubUpdateSource.newest(releases, after: ReleaseVersion("0.10.0")!) == nil)
print("PASS: signatures, tampering, version ordering, release selection, package bounds, platform and persistent opt-out")
