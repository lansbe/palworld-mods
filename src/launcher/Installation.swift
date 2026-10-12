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
        alert.messageText = "Install Palworld Mods"
        alert.informativeText = "Drag Palworld Mods into Applications, then open it from there."
        alert.addButton(withTitle: "Show Installer")
        alert.addButton(withTitle: "Quit")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
        }
        return true
    }
}
