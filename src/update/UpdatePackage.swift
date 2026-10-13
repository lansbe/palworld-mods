import Foundation
import Darwin

struct UpdatePackage {
    let directory: URL
    var app: URL { directory.appendingPathComponent("Palworld Mods.app") }
    var manifest: UpdateManifest {
        get throws {
            try UpdateManifest.verified(Data(contentsOf: directory.appendingPathComponent("manifest.json")),
                signature: Data(contentsOf: directory.appendingPathComponent("manifest.sig")))
        }
    }
    func extract() throws {
        let info = try manifest
        let archive = directory.appendingPathComponent("package.zip")
        try info.verifyArchive(archive)
        let names = try UpdateFiles.run("/usr/bin/unzip", ["-Z1", archive.path])
        guard let listing = String(data: names, encoding: .utf8), !listing.isEmpty else { throw UpdateFailure.invalidPackage }
        for name in listing.split(separator: "\n") {
            let parts = name.split(separator: "/")
            guard parts.first == "Palworld Mods.app", !parts.contains(".."), !parts.contains("."),
                  !name.hasPrefix("/"), !name.contains("\\"), !name.contains("\r") else { throw UpdateFailure.invalidPackage }
        }
        if FileManager.default.fileExists(atPath: app.path) { try FileManager.default.removeItem(at: app) }
        try UpdateFiles.run("/usr/bin/ditto", ["-x", "-k", archive.path, directory.path])
        try Self.validate(app, version: info.version)
    }
    static func metadata(_ app: URL) throws -> [String: Any] {
        // Bundle caches metadata by URL across an atomic exchange; read the installed bytes.
        let data = try Data(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
        guard data.count <= 65_536,
              let value = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { throw UpdateFailure.invalidPackage }
        return value
    }
    static func validate(_ app: URL, version: String) throws {
        let metadata = try metadata(app)
        guard metadata["CFBundleIdentifier"] as? String == "org.palworldmods.launcher",
              metadata["CFBundleShortVersionString"] as? String == version,
              let enumerator = FileManager.default.enumerator(at: app, includingPropertiesForKeys: [.isSymbolicLinkKey, .fileSizeKey])
        else { throw UpdateFailure.invalidPackage }
        var size = 0, count = 0
        for case let file as URL in enumerator {
            let values = try file.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
            size += values.fileSize ?? 0; count += 1
            guard values.isSymbolicLink != true, size <= 134_217_728, count <= 4096 else { throw UpdateFailure.invalidPackage }
        }
        for relative in ["MacOS/PalworldMods", "Helpers/UpdateInstaller", "Resources/libPalMods.dylib"] {
            let binary = app.appendingPathComponent("Contents/" + relative)
            let architecture = try UpdateFiles.run("/usr/bin/lipo", ["-archs", binary.path])
            guard String(data: architecture, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) == "arm64"
            else { throw UpdateFailure.invalidPackage }
        }
        try UpdateFiles.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
    }
    func install(over target: URL, expectedVersion: String) throws {
        let info = try manifest
        let current = try Self.metadata(target)
        guard current["CFBundleIdentifier"] as? String == info.bundleIdentifier,
              current["CFBundleShortVersionString"] as? String == expectedVersion,
              let previous = ReleaseVersion(expectedVersion), let next = ReleaseVersion(info.version), next > previous,
              target.standardizedFileURL == target.resolvingSymlinksInPath(),
              FileManager.default.isWritableFile(atPath: target.deletingLastPathComponent().path)
        else { throw UpdateFailure.storage }
        // Re-extract the signed archive; never trust a staging directory left between launches.
        try extract()
        let replacement = target.deletingLastPathComponent().appendingPathComponent(".PalworldMods-update-" + UUID().uuidString + ".app")
        try FileManager.default.copyItem(at: app, to: replacement)
        var exchanged = false
        defer { if !exchanged { try? FileManager.default.removeItem(at: replacement) } }
        try Self.validate(replacement, version: info.version)
        guard renameatx_np(AT_FDCWD, replacement.path, AT_FDCWD, target.path, UInt32(RENAME_SWAP)) == 0
        else { throw UpdateFailure.storage }
        exchanged = true
        do { try Self.validate(target, version: info.version) }
        catch {
            _ = renameatx_np(AT_FDCWD, replacement.path, AT_FDCWD, target.path, UInt32(RENAME_SWAP))
            throw error
        }
        // Keep one recoverable previous version, never an unbounded history of app bundles.
        let backup = target.deletingLastPathComponent().appendingPathComponent(".Palworld Mods.previous.app")
        if !FileManager.default.fileExists(atPath: backup.path) {
            try? FileManager.default.moveItem(at: replacement, to: backup)
        } else if (try? Self.metadata(backup)["CFBundleIdentifier"] as? String) == info.bundleIdentifier {
            do {
                try FileManager.default.removeItem(at: backup)
                try FileManager.default.moveItem(at: replacement, to: backup)
            } catch { /* Preserve the exchanged original if backup rotation fails. */ }
        }
    }
}
