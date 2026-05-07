import Foundation

enum TaskCaptureSplitter {
    private static let taskStarterLookahead = #"(?:(?:i\s+)?(?:need|have|want)\s+to\b|(?:i\s+)?(?:gotta|should|must)\b|remember\s+to\b|remind\s+me\s+to\b|don'?t\s+forget\s+to\b|do\s+not\s+forget\s+to\b)"#
    private static let taskStarterPattern = #"(?i)^(?:and\s+|also\s+|then\s+)?(?:(?:i\s+)?(?:need|have|want)\s+to|(?:i\s+)?(?:gotta|should|must)|remember\s+to|remind\s+me\s+to|don'?t\s+forget\s+to|do\s+not\s+forget\s+to)\s+"#
    private static let implicitTaskVerbLookahead = #"(?:(?:go|do|paint|sort|call|pay|clean|buy|get|schedule|book|make|wash|fold|start|finish|email|text|send|write|read|take|put|drop|return|order|prep|prepare|cook|plan|organize|organise|file|review|check|update|water|set|pack|unpack|vacuum|sweep|mop|wipe|declutter|refill|pick\s+up|take\s+out)\b)"#

    static func split(_ text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "•", with: "\n")

        let starterSeparated = insertSeparatorsBeforeRepeatedStarters(in: normalized)
        return starterSeparated
            .split(separator: "\n")
            .flatMap { splitImplicitTaskList(stripTaskStarter(from: String($0))) }
            .compactMap(cleanTaskText)
    }

    private static func insertSeparatorsBeforeRepeatedStarters(in text: String) -> String {
        var separated = text.replacingOccurrences(
            of: #"(?i)[\n;]+"#,
            with: "\n",
            options: .regularExpression
        )
        separated = separated.replacingOccurrences(
            of: #"(?i)\s*,\s*(?:and\s+|also\s+|then\s+)?(?="# + taskStarterLookahead + #")"#,
            with: "\n",
            options: .regularExpression
        )
        separated = separated.replacingOccurrences(
            of: #"(?i)\s+\b(?:and|also|then)\s+(?="# + taskStarterLookahead + #")"#,
            with: "\n",
            options: .regularExpression
        )
        return separated
    }

    private static func splitImplicitTaskList(_ text: String) -> [String] {
        var separated = text.replacingOccurrences(
            of: #"(?i)\s*,\s*(?:and\s+|also\s+|then\s+)?(?="# + implicitTaskVerbLookahead + #")"#,
            with: "\n",
            options: .regularExpression
        )
        separated = separated.replacingOccurrences(
            of: #"(?i)\s+\b(?:and|also|then)\s+(?="# + implicitTaskVerbLookahead + #")"#,
            with: "\n",
            options: .regularExpression
        )
        return separated.split(separator: "\n").map(String.init)
    }

    private static func stripTaskStarter(from text: String) -> String {
        text.replacingOccurrences(
            of: taskStarterPattern,
            with: "",
            options: .regularExpression
        )
    }

    private static func cleanTaskText(_ text: String) -> String? {
        var cleaned = stripTaskStarter(from: text)
            .replacingOccurrences(
                of: #"(?i)^(?:and|also|then)\s+"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: taskTrimCharacters)

        while let last = cleaned.last, ".!,;:".contains(last) {
            cleaned.removeLast()
            cleaned = cleaned.trimmingCharacters(in: taskTrimCharacters)
        }

        guard !cleaned.isEmpty else { return nil }
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    }

    private static var taskTrimCharacters: CharacterSet {
        .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".!,;:-"))
    }
}
