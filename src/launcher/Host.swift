import Foundation

final class Host {
    private let runtime: Runtime
    private let catalog: Catalog
    private let queue = DispatchQueue(label: "org.palworldmods.host")
    private var server: SocketServer?
    private let updates: UpdateController
    private var ready = false
    var onExit: ((Int32) -> Void)?
    let paths: Paths

    init(paths: Paths) throws {
        self.paths = paths
        updates = try UpdateController(root: paths.root, queue: queue)
        catalog = try Catalog(paths: paths)
        runtime = Runtime(paths: paths)
        updates.onChange = { [weak self] state in
            guard let self = self, self.ready else { return }
            self.runtime.call(["method": "updates.state", "state": state]) { _ in }
        }
        updates.note = { [weak self] in self?.runtime.note($0) }
        runtime.onEvent = { [weak self] event in self?.queue.async { self?.event(event) } }
        runtime.onExit = { [weak self] code in
            self?.queue.async {
                self?.server?.stop()
                self?.updates.gameExited(normally: code == 0)
                self?.onExit?(code)
            }
        }
    }

    func start() throws {
        server = SocketServer(path: paths.socket.path) { [weak self] request, reply in
            self?.queue.async { self?.command(request, reply: reply) }
        }
        try server?.start()
        do { try runtime.start(); updates.start() } catch { server?.stop(); throw error }
    }

    private func event(_ event: [String: Any]) {
        switch event["event"] as? String {
        case "ready":
            ready = true
            runtime.call(["method": "updates.state", "state": updates.snapshot]) { _ in }
            runtime.call(["method": "language.configure", "language": L10n.mode]) { _ in }
            runtime.call(["method": "mods.catalog", "catalog": catalog.listing()]) { _ in }
            for id in catalog.installed() { install(id) { [weak self] in self?.feedback($0) } }
        case "update_request":
            var request = event
            request["method"] = "updates." + ((event["operation"] as? String) ?? "")
            command(request) { [weak self] response in
                if response["ok"] as? Bool != true {
                    self?.runtime.call(["method": "mods.feedback", "key": "updates.failed"]) { _ in }
                }
            }
        case "language_detected":
            guard let language = event["language"] as? String else { return }
            do { try L10n.detected(language) }
            catch { runtime.note("Could not persist detected language") }
        case "language_request":
            guard let language = event["language"] as? String else { return }
            command(["method": "language.set", "language": language]) { [weak self] in self?.feedback($0) }
        case "mod_request":
            guard let id = event["mod"] as? String else { return }
            command(["method": "mods." + ((event["operation"] as? String) ?? ""), "mod": id]) { [weak self] in self?.feedback($0) }
        case "mod_state", "settings":
            do { try catalog.record(event) }
            catch { runtime.call(["method": "mods.feedback", "key": "error.save"]) { _ in } }
        default: break
        }
    }

    private func feedback(_ response: [String: Any]) {
        guard response["ok"] as? Bool != true else { return }
        runtime.call(["method": "mods.feedback", "key": "error.mod_change"]) { _ in }
        runtime.note("mod operation failed: \(response["result"] ?? "unknown error")")
    }

    private func install(_ id: String, reply: @escaping ([String: Any]) -> Void) {
        do { runtime.call(try catalog.installRequest(id), completion: reply) }
        catch { reply(["ok": false, "result": error.localizedDescription]) }
    }

    private func command(_ request: [String: Any], reply: @escaping ([String: Any]) -> Void) {
        guard let method = request["method"] as? String else { reply(["ok": false, "result": "Missing method."]); return }
        if method == "host.status" { reply(["ok": true, "result": ["running": runtime.running, "ready": ready, "api": 1]]); return }
        if method.hasPrefix("updates.") {
            do { reply(["ok": true, "result": try updates.command(request)]) }
            catch { reply(["ok": false, "result": L10n.text("updates.failed")]) }
            return
        }
        guard ready else { reply(["ok": false, "result": L10n.text("error.starting")]); return }
        if method == "language.set" {
            do {
                guard let language = request["language"] as? String else { throw HostError.message(L10n.text("error.language")) }
                try L10n.setMode(language)
                runtime.call(["method": "language.configure", "language": language], completion: reply)
            } catch { reply(["ok": false, "result": L10n.text("error.save")]) }
            return
        }
        if method == "mods.install" {
            guard let id = request["mod"] as? String else { reply(["ok": false, "result": "Missing mod ID."]); return }
            install(id, reply: reply); return
        }
        let allowed: Set<String> = ["language.get", "ping", "game.state", "game.action", "game.look", "game.move", "game.stop",
            "game.observe", "game.inventory", "game.path", "game.aim", "ui.list", "ui.open", "ui.activate", "ui.set_text", "ui.scroll", "ui.back",
            "mods.list", "mods.enable", "mods.remove", "mods.configure", "mods.call", "diagnostics", "display.get", "display.fullscreen", "quit"]
        guard allowed.contains(method) else { reply(["ok": false, "result": "Unknown method."]); return }
        runtime.call(request, completion: reply)
    }
}
