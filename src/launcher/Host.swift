import Foundation

final class Host {
    private let runtime: Runtime
    private let catalog: Catalog
    private let queue = DispatchQueue(label: "org.palworldmods.host")
    private var server: SocketServer?
    private var ready = false
    var onExit: ((Int32) -> Void)?
    let paths: Paths

    init(paths: Paths) throws {
        self.paths = paths
        catalog = try Catalog(paths: paths)
        runtime = Runtime(paths: paths)
        runtime.onEvent = { [weak self] event in self?.queue.async { self?.event(event) } }
        runtime.onExit = { [weak self] code in
            self?.server?.stop()
            self?.onExit?(code)
        }
    }

    func start() throws {
        server = SocketServer(path: paths.socket.path) { [weak self] request, reply in
            self?.queue.async { self?.command(request, reply: reply) }
        }
        try server?.start()
        do { try runtime.start() } catch { server?.stop(); throw error }
    }

    private func event(_ event: [String: Any]) {
        switch event["event"] as? String {
        case "ready":
            ready = true
            runtime.call(["method": "mods.catalog", "catalog": catalog.listing()]) { _ in }
            for id in catalog.installed() { install(id) { [weak self] in self?.feedback($0) } }
        case "mod_request":
            guard let id = event["mod"] as? String else { return }
            command(["method": "mods." + ((event["operation"] as? String) ?? ""), "mod": id]) { [weak self] in self?.feedback($0) }
        case "mod_state", "settings":
            do { try catalog.record(event) }
            catch { runtime.call(["method": "mods.feedback", "message": "Settings could not be saved."]) { _ in } }
        default: break
        }
    }

    private func feedback(_ response: [String: Any]) {
        guard response["ok"] as? Bool != true else { return }
        runtime.call(["method": "mods.feedback", "message": "The mod could not be changed. Check local diagnostics."]) { _ in }
        runtime.note("mod operation failed: \(response["result"] ?? "unknown error")")
    }

    private func install(_ id: String, reply: @escaping ([String: Any]) -> Void) {
        do { runtime.call(try catalog.installRequest(id), completion: reply) }
        catch { reply(["ok": false, "result": error.localizedDescription]) }
    }

    private func command(_ request: [String: Any], reply: @escaping ([String: Any]) -> Void) {
        guard let method = request["method"] as? String else { reply(["ok": false, "result": "Missing method."]); return }
        if method == "host.status" { reply(["ok": true, "result": ["running": runtime.running, "ready": ready, "api": 1]]); return }
        guard ready else { reply(["ok": false, "result": "Palworld is still starting."]); return }
        if method == "mods.install" {
            guard let id = request["mod"] as? String else { reply(["ok": false, "result": "Missing mod ID."]); return }
            install(id, reply: reply); return
        }
        let allowed: Set<String> = ["ping", "game.state", "game.action", "game.look", "game.move", "game.stop",
            "game.observe", "game.inventory", "game.path", "game.aim", "ui.list", "ui.open", "ui.activate", "ui.set_text", "ui.scroll", "ui.back",
            "mods.list", "mods.enable", "mods.remove", "mods.configure", "mods.call", "diagnostics", "display.get", "display.fullscreen", "quit"]
        guard allowed.contains(method) else { reply(["ok": false, "result": "Unknown method."]); return }
        runtime.call(request, completion: reply)
    }
}
