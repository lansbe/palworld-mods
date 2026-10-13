import Foundation

struct UpdatePreferences: Codable {
    var automatic = true
    var lastCheck: Date?
}

final class UpdateStore {
    let root: URL
    let folder: URL
    let preferencesURL: URL
    var preferences = UpdatePreferences()
    init(root: URL) throws {
        self.root = root; folder = root.appendingPathComponent("Updates", isDirectory: true)
        preferencesURL = root.appendingPathComponent("updates.json")
        try UpdateFiles.directory(folder)
        if let bytes = try? Data(contentsOf: preferencesURL), bytes.count <= 4096,
           let stored = try? JSONDecoder().decode(UpdatePreferences.self, from: bytes) { preferences = stored }
    }
    func save(_ value: UpdatePreferences) throws {
        try UpdateFiles.write(JSONEncoder().encode(value), to: preferencesURL)
        preferences = value
    }
    func stage(_ candidate: GitHubUpdateSource.Candidate, data: Data) throws -> URL {
        let directory = folder.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try UpdateFiles.directory(directory)
        do {
            try UpdateFiles.write(data, to: directory.appendingPathComponent("package.zip"))
            try UpdateFiles.write(candidate.document, to: directory.appendingPathComponent("manifest.json"))
            try UpdateFiles.write(candidate.signature, to: directory.appendingPathComponent("manifest.sig"))
            try UpdatePackage(directory: directory).extract()
            return directory
        } catch { try? FileManager.default.removeItem(at: directory); throw error }
    }
    func schedule(_ stage: URL, version: String) throws {
        let source = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/UpdateInstaller")
        let helper = folder.appendingPathComponent("UpdateInstaller")
        if FileManager.default.fileExists(atPath: helper.path) { try FileManager.default.removeItem(at: helper) }
        try FileManager.default.copyItem(at: source, to: helper)
        try UpdateFiles.run("/usr/bin/codesign", ["--verify", "--strict", helper.path])
        let process = Process()
        process.executableURL = helper
        process.arguments = [stage.path, Bundle.main.bundleURL.path, root.path, String(ProcessInfo.processInfo.processIdentifier), version]
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run()
    }
    func cleanStaging() {
        // Called only after acquiring the launcher lock, so no installer can own it.
        for url in (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [] {
            if UUID(uuidString: url.lastPathComponent) != nil { try? FileManager.default.removeItem(at: url) }
        }
    }
}
