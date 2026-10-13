// The release signing key stays in the developer's Keychain, never in the repository.
import Foundation
import Security
import CryptoKit

let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "org.palworldmods.release-signing", kSecAttrAccount as String: "ed25519-v1"]
var lookup = query
lookup[kSecReturnData as String] = true
var found: CFTypeRef?
let status = SecItemCopyMatching(lookup as CFDictionary, &found)
let arguments = CommandLine.arguments
let key: Curve25519.Signing.PrivateKey
if status == errSecSuccess, let data = found as? Data {
    key = try Curve25519.Signing.PrivateKey(rawRepresentation: data)
} else if status == errSecItemNotFound && arguments.count == 3 && arguments[1] == "initialize" {
    key = Curve25519.Signing.PrivateKey()
    var item = query
    item[kSecValueData as String] = key.rawRepresentation
    item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { fatalError("Cannot store signing key") }
} else { fatalError("Release signing key is unavailable; initialize it once on the release machine") }
if arguments.count == 3 && arguments[1] == "initialize" {
    let source = "import Foundation\n\nenum UpdateTrust {\n    static let publicKey = Data(base64Encoded: \"\(key.publicKey.rawRepresentation.base64EncodedString())\")!\n}\n"
    let destination = URL(fileURLWithPath: arguments[2])
    if FileManager.default.fileExists(atPath: destination.path) {
        guard try String(contentsOf: destination, encoding: .utf8) == source else { fatalError("Refusing to replace an existing update trust key") }
    } else { try source.write(to: destination, atomically: true, encoding: .utf8) }
} else if arguments.count == 4 && arguments[1] == "sign" {
    let data = try Data(contentsOf: URL(fileURLWithPath: arguments[2]))
    try key.signature(for: data).write(to: URL(fileURLWithPath: arguments[3]), options: .atomic)
} else { fatalError("Usage: update_signer.swift initialize PUBLIC_SOURCE | sign MANIFEST SIGNATURE") }
