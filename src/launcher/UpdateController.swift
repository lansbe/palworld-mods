import Foundation

// All state transitions run on the host queue; network and archive work never run on the game thread.
final class UpdateController: @unchecked Sendable {
    private let queue: DispatchQueue
    private let store: UpdateStore
    private let version: String
    private var task: Task<Void, Never>?
    private var timer: DispatchSourceTimer?
    private var generation = 0
    private var state = "idle"
    private var candidate: GitHubUpdateSource.Candidate?
    private var staged: URL?
    private var connecting = false
    private var lastPayload: Data?
    private var connected = false
    private var credential: String?
    private var credentialGeneration = 0
    var onChange: (([String: Any]) -> Void)?
    var note: ((String) -> Void)?

    init(root: URL, queue: DispatchQueue) throws {
        self.queue = queue; store = try UpdateStore(root: root)
        version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        store.cleanStaging()
        let result = root.appendingPathComponent("update-result.txt")
        if (try? String(contentsOf: result, encoding: .utf8)) == "failed\n" { state = "failed" }
        try? FileManager.default.removeItem(at: result)
    }
    var snapshot: [String: Any] {
        ["automatic": store.preferences.automatic, "status": state, "current": version,
         "version": candidate?.manifest.version ?? "", "connected": connected,
         "busy": connecting || task != nil || state == "checking" || state == "downloading", "available": candidate != nil, "ready": staged != nil]
    }
    private func changed(_ value: String? = nil) {
        if let value = value { state = value }
        let payload = try? JSONSerialization.data(withJSONObject: snapshot, options: [.sortedKeys])
        guard payload != lastPayload else { return }
        lastPayload = payload
        onChange?(snapshot)
    }
    func start() {
        let credentialVersion = credentialGeneration
        UpdateCredentials.load(provider: store.preferences.credentialSource) { [weak self] token in
            self?.queue.async {
                guard let self = self, self.credentialGeneration == credentialVersion else { return }
                self.credential = token; self.connected = token != nil; self.changed()
            }
        }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 10, repeating: 3600)
        timer.setEventHandler { [weak self] in
            guard let self = self, self.store.preferences.automatic, self.task == nil, self.staged == nil,
                  Date().timeIntervalSince(self.store.preferences.lastCheck ?? .distantPast) >= 21_600 else { return }
            self.check(automatic: true)
        }
        self.timer = timer; timer.resume()
    }
    func command(_ request: [String: Any]) throws -> [String: Any] {
        switch request["method"] as? String {
        case "updates.status": return snapshot
        case "updates.configure":
            guard let enabled = request["automatic"] as? Bool else { throw UpdateFailure.invalidPackage }
            var preference = store.preferences; preference.automatic = enabled
            try store.save(preference)
            if !enabled { cancel() } else if task == nil && staged == nil { check(automatic: true) }
        case "updates.check": guard task == nil && staged == nil else { throw UpdateFailure.busy }; check(automatic: false)
        case "updates.install":
            guard task == nil, staged == nil, let candidate = candidate else { throw UpdateFailure.busy }
            download(candidate)
        case "updates.connect":
            guard task == nil, !connecting else { throw UpdateFailure.busy }
            connecting = true
            credentialGeneration += 1; let credentialVersion = credentialGeneration
            UpdateCredentials.connect { [weak self] token, provider in
                self?.queue.async {
                    guard let self = self, self.credentialGeneration == credentialVersion else { return }
                    self.connecting = false
                    guard let token = token, let provider = provider else { self.changed("authentication"); return }
                    do {
                        var preference = self.store.preferences; preference.credentialSource = provider
                        try self.store.save(preference)
                        self.credential = token; self.connected = true; self.changed("idle")
                        self.check(automatic: self.store.preferences.automatic)
                    } catch { self.failed(error) }
                }
            }
        case "updates.disconnect":
            var preference = store.preferences; preference.credentialSource = nil
            try store.save(preference)
            credentialGeneration += 1; credential = nil; connecting = false
            UpdateCredentials.remove(); connected = false; cancel(); changed("authentication")
        default: throw UpdateFailure.invalidPackage
        }
        changed(); return snapshot
    }
    private func cancel() {
        generation += 1; task?.cancel(); task = nil; candidate = nil
        if let staged = staged { try? FileManager.default.removeItem(at: staged) }
        staged = nil; changed("idle")
    }
    private func source() -> GitHubUpdateSource? {
        guard let token = credential else { connected = false; changed("authentication"); return nil }
        connected = true; return GitHubUpdateSource(token: token)
    }
    private func failed(_ error: Error) {
        note?("update operation failed: \(String(describing: type(of: error))) code=\((error as NSError).code)")
        if (error as? UpdateFailure) == .authentication { connected = false }
        changed((error as? UpdateFailure) == .authentication ? "authentication" : "failed")
    }
    private func check(automatic: Bool) {
        guard task == nil, staged == nil, let source = source() else { return }
        generation += 1; let token = generation
        changed("checking")
        task = Task(priority: .utility) { [weak self] in
            guard let self = self else { return }
            do {
                let found = try await source.latest(after: self.version)
                try Task.checkCancellation()
                self.queue.async {
                    guard self.generation == token else { return }
                    self.task = nil; self.candidate = found
                    do {
                        var preference = self.store.preferences; preference.lastCheck = found == nil ? Date() : nil
                        try self.store.save(preference)
                    } catch { self.failed(error); return }
                    self.changed(found == nil ? "latest" : "available")
                    if automatic, self.store.preferences.automatic, let found = found { self.download(found) }
                }
            } catch {
                self.queue.async { guard self.generation == token else { return }; self.task = nil; self.failed(error) }
            }
        }
    }
    private func download(_ value: GitHubUpdateSource.Candidate) {
        guard let source = source() else { return }
        generation += 1; let token = generation
        changed("downloading")
        task = Task(priority: .utility) { [weak self] in
            guard let self = self else { return }
            do {
                let data = try await source.download(value.asset, limit: value.manifest.size)
                try Task.checkCancellation()
                let directory = try self.store.stage(value, data: data)
                self.queue.async {
                    guard self.generation == token else { try? FileManager.default.removeItem(at: directory); return }
                    self.task = nil; self.staged = directory; self.changed("ready")
                }
            } catch {
                self.queue.async { guard self.generation == token else { return }; self.task = nil; self.failed(error) }
            }
        }
    }
    func gameExited(normally: Bool) {
        timer?.cancel(); task?.cancel(); generation += 1
        guard normally, let staged = staged else { return }
        do { try store.schedule(staged, version: version); note?("update installation scheduled after clean shutdown") }
        catch { note?("update installer could not start") }
    }
}
