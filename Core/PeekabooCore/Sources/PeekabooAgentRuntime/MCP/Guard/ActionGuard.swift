import Foundation

/// A guard in front of MCP actions that change things the user cares about (openyard fork).
///
/// - A click or element action whose target label names a consequential step (Submit, Upload, Distribute,
///   Release, Delete, …) is refused until the caller repeats it with `confirm` set to that exact label. The
///   repeated call is what an approval layer in front of the MCP client (for example a PreToolUse hook)
///   can match and put in front of a person, because the label is then part of the tool input.
/// - A coordinate click in a sensitive app (Xcode and Transporter by default) has no label to check, so it
///   needs a `confirm` that says what is being clicked.
/// - Typing into, or setting the value of, a password field is refused: credentials are for the person.
///
/// Settings come from the JSON file named by `PEEKABOO_GUARD_CONFIG`, else `~/.peekaboo/guard.json`, else
/// the defaults below. `"enabled": false` turns the guard off.
public struct ActionGuard: Sendable, Equatable {
    public struct Config: Codable, Sendable, Equatable {
        public var enabled: Bool?
        public var confirmLabels: [String]?
        public var sensitiveApps: [String]?
        public var blockSecureFields: Bool?

        public init(
            enabled: Bool? = nil,
            confirmLabels: [String]? = nil,
            sensitiveApps: [String]? = nil,
            blockSecureFields: Bool? = nil)
        {
            self.enabled = enabled
            self.confirmLabels = confirmLabels
            self.sensitiveApps = sensitiveApps
            self.blockSecureFields = blockSecureFields
        }
    }

    public static let defaultConfirmLabels = [
        "submit", "upload", "distribute", "release", "publish", "roll ?out", "deploy", "send", "delete",
        "remove", "erase", "revoke", "pay", "purchase", "buy", "subscribe", "sign ?in", "log ?in", "approve",
        "confirm", "transfer", "install",
    ]
    public static let defaultSensitiveApps = ["Xcode", "Transporter"]

    public let enabled: Bool
    /// Regex source, compiled when used, so the guard stays a plain Sendable value.
    public let confirmPattern: String?
    public let sensitiveApps: [String]
    public let blockSecureFields: Bool

    public init(config: Config = Config()) {
        self.enabled = config.enabled ?? true
        let words = config.confirmLabels ?? Self.defaultConfirmLabels
        self.confirmPattern = words.isEmpty ? nil : "\\b(?:" + words.joined(separator: "|") + ")\\b"
        self.sensitiveApps = (config.sensitiveApps ?? Self.defaultSensitiveApps).map { $0.lowercased() }
        self.blockSecureFields = config.blockSecureFields ?? true
    }

    /// The guard for this process, read once.
    public static let shared: ActionGuard = Self.load()

    public static func load(environment: [String: String] = ProcessInfo.processInfo.environment) -> ActionGuard {
        let path = environment["PEEKABOO_GUARD_CONFIG"] ??
            (NSHomeDirectory() as NSString).appendingPathComponent(".peekaboo/guard.json")
        guard let data = FileManager.default.contents(atPath: path) else { return ActionGuard() }
        guard let config = try? JSONDecoder().decode(Config.self, from: data) else {
            // A config that does not parse must not switch the guard off.
            return ActionGuard()
        }
        return ActionGuard(config: config)
    }

    /// Checks every name the target has (title, label, description, the query text, ...). The first one that
    /// names a consequential step is the label `confirm` must repeat.
    public func checkClick(labels: [String?], app: String?, isCoordinate: Bool, confirm: String?) -> String? {
        let names = labels.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let label = isCoordinate ? nil : (names.first { self.needsConfirmation($0) } ?? names.first)
        return self.checkClick(label: label, app: app, isCoordinate: isCoordinate, confirm: confirm)
    }

    /// Returns a refusal message, or nil when the click may go ahead.
    public func checkClick(label: String?, app: String?, isCoordinate: Bool, confirm: String?) -> String? {
        guard self.enabled else { return nil }
        let confirm = confirm?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let location = app.map { " in \($0)" } ?? ""
        if isCoordinate {
            guard let app, self.sensitiveApps.contains(app.lowercased()) else { return nil }
            if !confirm.isEmpty { return nil }
            return """
            Guard: a coordinate click\(location) needs confirmation. Call click again with the same arguments and \
            confirm set to the name of what you are clicking, for example confirm: "Distribute App".
            """
        }
        let text = (label ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, self.needsConfirmation(text) else { return nil }
        if confirm.caseInsensitiveCompare(text) == .orderedSame { return nil }
        return """
        Guard: "\(text)"\(location) is a consequential step and needs confirmation. Call again with the same \
        arguments plus confirm: "\(text)".
        """
    }

    /// Returns a refusal message when the target is a password field.
    public func checkTextEntry(role: String?, roleDescription: String?) -> String? {
        guard self.enabled, self.blockSecureFields else { return nil }
        let role = role ?? ""
        let description = roleDescription ?? ""
        let secure = role.range(of: "SecureTextField", options: .caseInsensitive) != nil ||
            description.range(of: "secure", options: .caseInsensitive) != nil ||
            description.range(of: "password", options: .caseInsensitive) != nil
        guard secure else { return nil }
        return """
        Guard: this is a password field. Do not type credentials; stop and ask the person to sign in themselves.
        """
    }

    public func needsConfirmation(_ label: String) -> Bool {
        guard let source = self.confirmPattern,
              let pattern = try? NSRegularExpression(pattern: source, options: [.caseInsensitive])
        else { return false }
        let range = NSRange(label.startIndex..<label.endIndex, in: label)
        return pattern.firstMatch(in: label, range: range) != nil
    }
}
