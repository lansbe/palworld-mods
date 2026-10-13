import AppKit
import Security
import LocalAuthentication

enum UpdateCredentials {
    private static let queue = DispatchQueue(label: "org.palworldmods.credentials", qos: .utility)
    private static let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "org.palworldmods.updates", kSecAttrAccount as String: "github"]
    private static func read() -> String? {
        PalModsKeychainInteraction(false)
        var request = query
        request[kSecReturnData as String] = true
        let context = LAContext(); context.interactionNotAllowed = true
        request[kSecUseAuthenticationContext as String] = context
        var value: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &value) == errSecSuccess, let bytes = value as? Data
        else { return nil }
        return String(data: bytes, encoding: .utf8)
    }
    private static func save(_ token: String) throws {
        let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 20, value.count <= 512, !value.contains(where: { $0.isWhitespace })
        else { throw UpdateFailure.authentication }
        // Explicit connection is the only path allowed to request Keychain access.
        PalModsKeychainInteraction(true)
        defer { PalModsKeychainInteraction(false) }
        let fields: [String: Any] = [kSecValueData as String: Data(value.utf8)]
        let status = SecItemUpdate(query as CFDictionary, fields as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item.merge(fields) { _, new in new }
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw UpdateFailure.storage }
        } else if status != errSecSuccess { throw UpdateFailure.storage }
    }
    private static func cliToken() -> String? {
        for executable in ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"] {
            guard FileManager.default.isExecutableFile(atPath: executable) else { continue }
            let process = Process(), output = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = ["auth", "token", "--hostname", "github.com"]
            process.standardOutput = output; process.standardError = FileHandle.nullDevice
            do { try process.run() } catch { continue }
            let deadline = Date().addingTimeInterval(3)
            while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
            if process.isRunning { process.terminate(); continue }
            guard process.terminationStatus == 0 else { continue }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            guard data.count <= 1024, let value = String(data: data, encoding: .utf8) else { continue }
            let token = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty { return token }
        }
        return nil
    }
    static func load(provider: String?, completion: @escaping (String?) -> Void) {
        queue.async {
            switch provider {
            case "github-cli": completion(cliToken())
            case "keychain": completion(read())
            default: completion(nil)
            }
        }
    }
    static func remove() {
        queue.async { PalModsKeychainInteraction(false); SecItemDelete(query as CFDictionary) }
    }
    static func connect(_ completion: @escaping (String?, String?) -> Void) {
        queue.async {
            if let token = cliToken() {
                // Persist only the selected provider; gh retains its own Keychain credential.
                completion(token, "github-cli"); return
            }
            DispatchQueue.main.async {
                let app = NSApplication.shared
                app.setActivationPolicy(.accessory); app.activate(ignoringOtherApps: true)
                let alert = NSAlert()
                alert.messageText = L10n.text("updates.connect")
                alert.informativeText = L10n.text("updates.token_hint")
                let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 380, height: 24))
                alert.accessoryView = field
                alert.addButton(withTitle: L10n.text("common.ok"))
                alert.addButton(withTitle: L10n.text("common.back"))
                let accepted = alert.runModal() == .alertFirstButtonReturn
                let token = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                field.stringValue = ""; app.setActivationPolicy(.prohibited)
                queue.async {
                    guard accepted else { completion(nil, nil); return }
                    do { try save(token); completion(token, "keychain") }
                    catch { completion(nil, nil) }
                }
            }
        }
    }
}
