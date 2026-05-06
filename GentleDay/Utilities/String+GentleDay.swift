import Foundation

extension String {
    var trimmedForStorage: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfBlank: String? {
        let value = trimmedForStorage
        return value.isEmpty ? nil : value
    }
}

