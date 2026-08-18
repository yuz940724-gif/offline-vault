import Foundation
import SwiftData

@Model
final class PasswordEntry: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var username: String
    var encryptedPassword: Data
    var url: String?
    var notes: String?
    var isFavorite: Bool
    var category: String?
    // Legacy field retained so existing SwiftData stores can open safely.
    // The app no longer reads or writes secondary groups.
    var subcategory: String?
    // Keep a persistent default so the V1 -> V2 lightweight migration can
    // backfill existing entries without making the old store unreadable.
    var sortOrder: Int = 0
    var createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        username: String,
        encryptedPassword: Data,
        url: String? = nil,
        notes: String? = nil,
        isFavorite: Bool = false,
        category: String? = nil,
        subcategory: String? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.username = username
        self.encryptedPassword = encryptedPassword
        self.url = url
        self.notes = notes
        self.isFavorite = isFavorite
        self.category = category
        self.subcategory = subcategory
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastUsedAt = lastUsedAt
    }
}

@Model
final class PasswordGroup: Identifiable {
    @Attribute(.unique) var id: UUID
    var category: String
    // Legacy field retained for store compatibility; always nil for new data.
    var subcategory: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        category: String,
        subcategory: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.subcategory = subcategory
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension PasswordEntry {
    var groupPath: String? {
        guard let category else { return nil }
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

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
