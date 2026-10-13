import Foundation
import Darwin

struct Paths {
    let root: URL
    let resources: URL
    var socket: URL { root.appendingPathComponent("control.sock") }
    var state: URL { root.appendingPathComponent("settings.json") }
    var log: URL { root.appendingPathComponent("runtime.log") }

    init(resources: URL) throws {
        self.resources = resources
        root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PalworldMods", isDirectory: true)
        for directory in [root] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            chmod(directory.path, 0o700)
        }
    }

    func game() throws -> URL {
        let applications = [URL(fileURLWithPath: "/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
        for directory in applications {
            let app = directory.appendingPathComponent("Palworld.app")
            if Bundle(url: app)?.bundleIdentifier == "com.pocketpair.palworld.mac" {
                return app.appendingPathComponent("Contents/MacOS/Palworld")
            }
        }
        throw HostError.message(L10n.text("launcher.missing_game"))
    }
}

enum HostError: Error, LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let value) = self { return value }; return nil }
}

func jsonData(_ value: Any) throws -> Data {
    guard JSONSerialization.isValidJSONObject(value) else { throw HostError.message(L10n.text("error.json")) }
    let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    guard data.count <= 1_048_576 else { throw HostError.message(L10n.text("error.size")) }
    return data
}
