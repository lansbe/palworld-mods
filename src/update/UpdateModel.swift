import Foundation
import CryptoKit

enum UpdateFailure: Error { case authentication, network, invalidPackage, storage, busy }

struct ReleaseVersion: Comparable, Equatable {
    let parts: [Int]
    init?(_ value: String) {
        let pieces = value.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count == 3, pieces.allSatisfy({ !$0.isEmpty && $0.allSatisfy({ $0.isASCII && $0.isNumber }) }),
              pieces.allSatisfy({ $0.count == 1 || !$0.hasPrefix("0") }) else { return nil }
        let numbers = pieces.compactMap { Int($0) }
        guard numbers.count == 3 else { return nil }
        parts = numbers
    }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.parts.lexicographicallyPrecedes(rhs.parts) }
}

struct UpdateManifest: Codable {
    let schema: Int
    let version: String
    let bundleIdentifier: String
    let minimumSystemVersion: String
    let archive: String
    let sha256: String
    let size: Int

    static func verified(_ data: Data, signature: Data, publicKey: Data = UpdateTrust.publicKey) throws -> Self {
        guard data.count <= 16_384, signature.count == 64,
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKey),
              key.isValidSignature(signature, for: data) else { throw UpdateFailure.invalidPackage }
        let value = try JSONDecoder().decode(Self.self, from: data)
        guard value.schema == 1, ReleaseVersion(value.version) != nil,
              value.bundleIdentifier == "org.palworldmods.launcher",
              value.archive == "palworld-mods-\(value.version)-macos-arm64.zip",
              value.size > 0, value.size <= 67_108_864,
              value.sha256.count == 64, value.sha256.allSatisfy({ "0123456789abcdef".contains($0) }),
              let required = ReleaseVersion(value.minimumSystemVersion) else { throw UpdateFailure.invalidPackage }
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let installed = ReleaseVersion("\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)")!
        guard installed >= required else { throw UpdateFailure.invalidPackage }
        return value
    }

    func verifyArchive(_ url: URL) throws {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count == size, SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == sha256
        else { throw UpdateFailure.invalidPackage }
    }
}

enum UpdateFiles {
    static func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    static func directory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }
    @discardableResult static func run(_ executable: String, _ arguments: [String]) throws -> Data {
        let process = Process(), output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
        process.standardOutput = output; process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateFailure.invalidPackage }
        return data
    }
}
