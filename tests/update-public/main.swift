import Foundation

// Opt-in network integration: never reads a credential or changes an installed app.
let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
Task {
    do {
        defer { try? FileManager.default.removeItem(at: root) }
        let source = GitHubUpdateSource(token: nil)
        guard let candidate = try await source.latest(after: "0.0.0") else { fatalError("No signed public release") }
        let data = try await source.download(candidate.asset, limit: candidate.manifest.size)
        let store = try UpdateStore(root: root)
        let stage = try store.stage(candidate, data: data)
        let license = try String(contentsOf: stage.appendingPathComponent("Palworld Mods.app/Contents/Resources/LICENSE"), encoding: .utf8)
        guard license.hasPrefix("MIT License\n") else { fatalError("Missing MIT license") }
        print("PASS: anonymous public release download, signature, archive and app validation (\(candidate.manifest.version))")
        exit(0)
    } catch { fputs("Public update integration failed: \(error)\n", stderr); exit(1) }
}
dispatchMain()
