import Foundation

enum CrashDiagnostics {
    static func collect(paths: Paths, since: Date) {
        let manager = FileManager.default
        let directory = manager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/DiagnosticReports")
        guard let files = try? manager.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else { return }
        let candidates = files.filter { file in
            guard ["ips", "crash"].contains(file.pathExtension),
                let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                (values.contentModificationDate ?? .distantPast) >= since,
                (values.fileSize ?? Int.max) <= 4_194_304 else { return false }
            return file.lastPathComponent.hasPrefix("Pal-") || file.lastPathComponent.hasPrefix("Palworld-")
        }.sorted { $0.lastPathComponent > $1.lastPathComponent }
        guard let source = candidates.first else { return }
        let destination = paths.root.appendingPathComponent("latest-game-crash." + source.pathExtension)
        try? manager.removeItem(at: destination)
        do {
            try manager.copyItem(at: source, to: destination)
            try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        } catch { /* The original macOS report remains available if collection fails. */ }
    }
}
