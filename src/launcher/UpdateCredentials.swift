import AppKit
import Security
import LocalAuthentication

// Private-repository access is optional and stays in the login Keychain.
enum UpdateCredentials {
    private static let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "org.palworldmods.updates", kSecAttrAccount as String: "github"]
    static func read() -> String? {
        var request = query
        request[kSecReturnData as String] = true
        let context = LAContext(); context.interactionNotAllowed = true
        request[kSecUseAuthenticationContext as String] = context
        var value: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &value) == errSecSuccess, let bytes = value as? Data
        else { return nil }
        return String(data: bytes, encoding: .utf8)
    }
    static func save(_ token: String) throws {
        let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 20, value.count <= 512, !value.contains(where: { $0.isWhitespace })
        else { throw UpdateFailure.authentication }
        let fields: [String: Any] = [kSecValueData as String: Data(value.utf8)]
        let status = SecItemUpdate(query as CFDictionary, fields as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item.merge(fields) { _, new in new }
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw UpdateFailure.storage }
        } else if status != errSecSuccess { throw UpdateFailure.storage }
    }
    static func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw UpdateFailure.storage }
    }
    static func connect(_ completion: @escaping (Bool) -> Void) {
        // Reuse an existing CLI login only after the user chooses Connect GitHub.
        DispatchQueue.global(qos: .utility).async {
            for executable in ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"] {
                if FileManager.default.isExecutableFile(atPath: executable),
                   let data = try? UpdateFiles.run(executable, ["auth", "token", "--hostname", "github.com"]),
                   let token = String(data: data, encoding: .utf8), (try? save(token)) != nil {
                    completion(true); return
                }
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
                let saved = accepted && (try? save(field.stringValue)) != nil
                field.stringValue = ""
                app.setActivationPolicy(.prohibited)
                completion(saved)
            }
        }
    }
}
