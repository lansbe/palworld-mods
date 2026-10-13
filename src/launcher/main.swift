import Foundation
import AppKit
import Darwin

signal(SIGPIPE, SIG_IGN)
let application = NSApplication.shared
application.setActivationPolicy(.prohibited)
if Installation.presentIfNeeded() { exit(0) }
var retainedHost: Host?
var launchLock: Int32 = -1

func fail(_ error: Error) -> Never {
    application.setActivationPolicy(.accessory)
    let alert = NSAlert()
    alert.messageText = "Palworld Mods"
    alert.informativeText = error.localizedDescription
    alert.alertStyle = .warning
    alert.addButton(withTitle: L10n.text("common.ok"))
    alert.runModal()
    exit(1)
}

do {
    guard let resources = Bundle.main.resourceURL else { throw HostError.message(L10n.text("launcher.bundle")) }
    let paths = try Paths(resources: resources)
    launchLock = open(paths.root.appendingPathComponent("launcher.lock").path, O_CREAT | O_RDWR | O_CLOEXEC, 0o600)
    guard launchLock >= 0 else { throw HostError.message(L10n.text("launcher.lock")) }
    if flock(launchLock, LOCK_EX | LOCK_NB) != 0 { exit(0) }
    if !NSRunningApplication.runningApplications(withBundleIdentifier: "com.pocketpair.palworld.mac").isEmpty {
        throw HostError.message(L10n.text("launcher.already_open"))
    }
    let host = try Host(paths: paths)
    retainedHost = host
    host.onExit = { code in
        DispatchQueue.main.async {
            if code != 0 {
                fputs("Palworld exited unexpectedly. Local diagnostics are available in Application Support/PalworldMods.\n", stderr)
            }
            exit(code == 0 ? 0 : 1)
        }
    }
    try host.start()
    application.run()
} catch { fail(error) }
