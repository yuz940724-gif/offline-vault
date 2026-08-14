import Foundation
import SwiftData

@Model
final class PasswordEntry {
    @Attribute(.unique) var id: UUID
    var title: String
    var username: String
    var encryptedPassword: Data
    var url: String?
    var notes: String?
    var isFavorite: Bool
    var category: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        username: String,
        encryptedPassword: Data,
        url: String? = nil,
        notes: String? = nil,
        isFavorite: Bool = false,
        category: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.username = username
        self.encryptedPassword = encryptedPassword
        self.url = url
        self.notes = notes
        self.isFavorite = isFavorite
        self.category = category
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension PasswordEntry {
    func matches(query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        if title.localizedCaseInsensitiveContains(needle) { return true }
        if username.localizedCaseInsensitiveContains(needle) { return true }
        if notes?.localizedCaseInsensitiveContains(needle) == true { return true }
        if url?.localizedCaseInsensitiveContains(needle) == true { return true }
        if category?.localizedCaseInsensitiveContains(needle) == true { return true }
        return false
    }
}
