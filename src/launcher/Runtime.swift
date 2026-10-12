import Foundation
import Darwin

final class Runtime {
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private let writes = NSLock()
    private let pendingLock = NSLock()
    private let logLock = NSLock()
    private var pending: [String: ([String: Any]) -> Void] = [:]
    private var buffer = Data()
    private var dropping = false
    private let paths: Paths
    private let launchedAt = Date()
    var onEvent: (([String: Any]) -> Void)?
    var onExit: ((Int32) -> Void)?
    var running: Bool { process.isRunning }

    init(paths: Paths) { self.paths = paths }

    func start() throws {
        let game = try paths.game()
        process.executableURL = game
        process.arguments = ["-nosplash", "-windowed"]
        var environment = ProcessInfo.processInfo.environment
        environment["DYLD_INSERT_LIBRARIES"] = paths.resources.appendingPathComponent("libPalMods.dylib").path
        process.environment = environment
        process.standardInput = input
        process.standardOutput = output
        process.standardError = output
        if let attributes = try? FileManager.default.attributesOfItem(atPath: paths.log.path),
            let date = attributes[.modificationDate] as? Date { CrashDiagnostics.collect(paths: paths, since: date) }
        rotateLog()
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty { self?.consume(data) }
        }
        process.terminationHandler = { [weak self] process in
            guard let self = self else { return }
            self.output.fileHandleForReading.readabilityHandler = nil
            self.pendingLock.lock(); let waiting = self.pending; self.pending.removeAll(); self.pendingLock.unlock()
            for reply in waiting.values { reply(["ok": false, "result": "Palworld has exited."]) }
            self.note("exit status=\(process.terminationStatus) reason=\(process.terminationReason.rawValue)")
            if process.terminationStatus != 0 { CrashDiagnostics.collect(paths: self.paths, since: self.launchedAt) }
            self.onExit?(process.terminationStatus)
        }
        try process.run()
        note("launch pid=\(process.processIdentifier) runtime=0.1.0")
    }

    func call(_ request: [String: Any], completion: @escaping ([String: Any]) -> Void) {
        guard process.isRunning else { completion(["ok": false, "result": "Palworld is not running."]); return }
        var payload = request
        let id = UUID().uuidString
        payload["id"] = id
        note("command \(request["method"] as? String ?? "unknown") id=\(id)")
        do {
            var data = try jsonData(payload); data.append(10)
            pendingLock.lock()
            guard pending.count < 32 else {
                pendingLock.unlock(); completion(["ok": false, "result": "The command queue is full."]); return
            }
            pending[id] = completion; pendingLock.unlock()
            writes.lock(); defer { writes.unlock() }
            try input.fileHandleForWriting.write(contentsOf: data)
            DispatchQueue.global().asyncAfter(deadline: .now() + 15) { [weak self] in
                guard let self = self else { return }
                self.pendingLock.lock(); let reply = self.pending.removeValue(forKey: id); self.pendingLock.unlock()
                reply?(["ok": false, "result": "The game did not answer within 15 seconds."])
            }
        } catch {
            pendingLock.lock(); pending.removeValue(forKey: id); pendingLock.unlock()
            completion(["ok": false, "result": error.localizedDescription])
        }
    }

    private func consume(_ data: Data) {
        for byte in data {
            if byte == 10 {
                if !dropping { line(buffer) }
                buffer.removeAll(keepingCapacity: true); dropping = false
            } else if !dropping {
                if buffer.count < 1_048_600 { buffer.append(byte) }
                else { dropping = true; buffer.removeAll(keepingCapacity: true) }
            }
        }
    }

    private func line(_ data: Data) {
        let prefix = Data("[PalModsIPC]".utf8)
        if data.starts(with: prefix) {
            guard let event = try? JSONSerialization.jsonObject(with: data.dropFirst(prefix.count)) as? [String: Any] else { return }
            if let id = event["id"] as? String {
                pendingLock.lock(); let reply = pending.removeValue(forKey: id); pendingLock.unlock()
                note("response id=\(id) ok=\(event["ok"] as? Bool == true)")
                reply?(event)
            } else { onEvent?(event) }
        } else {
            appendLog(data)
        }
    }

    func note(_ message: String) {
        appendLog(Data("[PalMods] \(ISO8601DateFormatter().string(from: Date())) \(message)".utf8))
    }

    private func rotateLog() {
        let previous = paths.root.appendingPathComponent("previous-runtime.log")
        try? FileManager.default.removeItem(at: previous)
        if FileManager.default.fileExists(atPath: paths.log.path) { try? FileManager.default.moveItem(at: paths.log, to: previous) }
        FileManager.default.createFile(atPath: paths.log.path, contents: nil, attributes: [.posixPermissions: 0o600])
    }

    private func appendLog(_ data: Data) {
        logLock.lock(); defer { logLock.unlock() }
        guard let handle = try? FileHandle(forWritingTo: paths.log) else { return }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        if size > 2_097_152 { try? handle.truncate(atOffset: 0); try? handle.seek(toOffset: 0) }
        var row = data.prefix(16384); row.append(10)
        try? handle.write(contentsOf: row)
    }
}
