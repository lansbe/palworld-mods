import Foundation
import CryptoKit

final class Catalog {
    private let paths: Paths
    private var state: [String: Any]
    private(set) var packages: [String: [String: Any]] = [:]

    init(paths: Paths) throws {
        self.paths = paths
        if FileManager.default.fileExists(atPath: paths.state.path) {
            state = try JSONSerialization.jsonObject(with: Data(contentsOf: paths.state)) as? [String: Any] ?? [:]
        } else {
            state = ["minimap": ["installed": true, "settings": [:]]]
        }
        let folder = paths.resources.appendingPathComponent("Catalog")
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        for file in files where file.pathExtension == "json" {
            let bytes = try Data(contentsOf: file)
            guard bytes.count <= 1_048_576,
                let package = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
                let id = package["id"] as? String, ["minimap", "autonomy"].contains(id),
                package["api"] as? Int == 1, package["files"] is [String: String] else {
                throw HostError.message(L10n.text("error.catalog"))
            }
            let expected = try String(contentsOf: file.deletingPathExtension().appendingPathExtension("sha256"), encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
            guard digest == expected else { throw HostError.message(L10n.text("error.integrity")) }
            packages[id] = package
        }
    }

    func listing() -> [[String: Any]] {
        ["minimap", "autonomy"].filter { packages[$0] != nil }.map { ["id": $0, "name": packages[$0]?["name"] ?? $0, "translations": packages[$0]?["translations"] ?? [:]] }
    }

    func installed() -> [String] {
        packages.keys.sorted().filter { (state[$0] as? [String: Any])?["installed"] as? Bool == true }
    }

    func installRequest(_ id: String) throws -> [String: Any] {
        guard let package = packages[id] else { throw HostError.message(L10n.text("error.unknown_mod")) }
        return ["method": "mods.install", "package": package,
            "settings": (state[id] as? [String: Any])?["settings"] ?? [:],
            "enabled": (state[id] as? [String: Any])?["enabled"] ?? true]
    }

    func record(_ event: [String: Any]) throws {
        guard let id = event["mod"] as? String, packages[id] != nil else { return }
        var item = state[id] as? [String: Any] ?? [:]
        if let installed = event["installed"] as? Bool { item["installed"] = installed }
        if let enabled = event["enabled"] as? Bool { item["enabled"] = enabled }
        if let settings = event["settings"] as? [String: Any] { item["settings"] = settings }
        state[id] = item
        try jsonData(state).write(to: paths.state, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: paths.state.path)
    }
}
