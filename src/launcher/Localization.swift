import Foundation

// Only display strings are translated. Protocol identifiers and diagnostic logs stay stable.
enum L10n {
    private static let lock = NSRecursiveLock()
    private static let folder = Bundle.main.resourceURL?.appendingPathComponent("Locales")
    private static var cache: [String: [String: String]] = [:]
    static let languages = ["en", "fr", "de", "es", "es-419", "it", "pt-BR", "pl", "ru", "tr", "id", "vi", "th", "ja", "ko", "zh-Hans", "zh-Hant"]
    private static let preferenceURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("PalworldMods/preferences.json")
    private static var preference: [String: String] = {
        guard let bytes = try? Data(contentsOf: preferenceURL), bytes.count <= 4096,
              let saved = try? JSONDecoder().decode([String: String].self, from: bytes) else { return [:] }
        return saved
    }()

    static func normalize(_ value: String) -> String {
        let tag = value.replacingOccurrences(of: "_", with: "-").lowercased()
        if let exact = languages.first(where: { $0.lowercased() == tag }) { return exact }
        if tag.hasPrefix("zh") {
            return tag.contains("hant") || ["zh-tw", "zh-hk", "zh-mo"].contains(where: { tag.hasPrefix($0) }) ? "zh-Hant" : "zh-Hans"
        }
        if tag.hasPrefix("es-"), !tag.hasPrefix("es-es") { return "es-419" }
        if tag.hasPrefix("pt") { return "pt-BR" }
        let base = tag.components(separatedBy: "-")[0]
        return languages.contains(base) ? base : "en"
    }

    static var mode: String {
        lock.lock(); defer { lock.unlock() }
        let value = preference["language"] ?? "auto"
        return value == "auto" || languages.contains(value) ? value : "auto"
    }

    static var language: String {
        lock.lock(); defer { lock.unlock() }
        return mode == "auto" ? normalize(preference["game_language"] ?? Locale.preferredLanguages.first ?? "en") : mode
    }

    static func setMode(_ value: String) throws {
        guard value == "auto" || languages.contains(value) else { throw HostError.message(text("error.language")) }
        try save("language", value)
    }

    static func detected(_ value: String) throws { try save("game_language", normalize(value)) }

    private static func save(_ key: String, _ value: String) throws {
        lock.lock(); defer { lock.unlock() }
        guard preference[key] != value else { return }
        var updated = preference; updated[key] = value
        let bytes = try JSONEncoder().encode(updated)
        try bytes.write(to: preferenceURL, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: preferenceURL.path)
        preference = updated
    }

    private static func catalogue(_ language: String) -> [String: String] {
        if let existing = cache[language] { return existing }
        guard let path = folder?.appendingPathComponent(language + ".json"),
              let bytes = try? Data(contentsOf: path),
              let strings = try? JSONDecoder().decode([String: String].self, from: bytes) else { return [:] }
        cache[language] = strings; return strings
    }

    static func text(_ key: String, _ arguments: [String: String] = [:]) -> String {
        lock.lock(); defer { lock.unlock() }
        var result = catalogue(language)[key] ?? catalogue("en")[key] ?? key
        for (name, value) in arguments { result = result.replacingOccurrences(of: "{" + name + "}", with: value) }
        return result
    }
}
