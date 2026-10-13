import AppKit

enum Installation {
    static func requiresCopy(_ bundle: URL) -> Bool {
        let values = try? bundle.resourceValues(forKeys: [.volumeIsReadOnlyKey])
        return values?.volumeIsReadOnly == true
    }

    static func presentIfNeeded() -> Bool {
        guard requiresCopy(Bundle.main.bundleURL) else { return false }
        NSApplication.shared.setActivationPolicy(.accessory)
        NSApplication.shared.finishLaunching()
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L10n.text("launcher.install")
        alert.informativeText = L10n.text("launcher.instruction")
        alert.addButton(withTitle: L10n.text("launcher.show"))
        alert.addButton(withTitle: L10n.text("common.quit"))
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
        }
        return true
    }
}
