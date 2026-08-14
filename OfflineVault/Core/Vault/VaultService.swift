import Foundation
import SwiftData

@MainActor
@Observable
final class VaultService {
    private let modelContext: ModelContext
    private let session: SessionController

    init(modelContext: ModelContext, session: SessionController) {
        self.modelContext = modelContext
        self.session = session
    }

    func decryptPassword(_ entry: PasswordEntry) throws -> String {
        let key = try session.currentDataKey()
        return try AESGCMCipher.decryptString(entry.encryptedPassword, key: key)
    }

    func create(
        title: String,
        username: String,
        password: String,
        url: String?,
        notes: String?,
        category: String?,
        isFavorite: Bool
    ) throws {
        let key = try session.currentDataKey()
        let encrypted = try AESGCMCipher.encryptString(password, key: key)
        let now = Date()
        let entry = PasswordEntry(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            encryptedPassword: encrypted,
            url: Self.normalizedOptional(url),
            notes: Self.normalizedOptional(notes),
            isFavorite: isFavorite,
            category: Self.normalizedOptional(category),
            createdAt: now,
            updatedAt: now
        )
        modelContext.insert(entry)
        try modelContext.save()
    }

    func update(
        _ entry: PasswordEntry,
        title: String,
        username: String,
        password: String,
        url: String?,
        notes: String?,
        category: String?,
        isFavorite: Bool
    ) throws {
        let key = try session.currentDataKey()
        entry.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.encryptedPassword = try AESGCMCipher.encryptString(password, key: key)
        entry.url = Self.normalizedOptional(url)
        entry.notes = Self.normalizedOptional(notes)
        entry.category = Self.normalizedOptional(category)
        entry.isFavorite = isFavorite
        entry.updatedAt = Date()
        try modelContext.save()
    }

    func toggleFavorite(_ entry: PasswordEntry) throws {
        entry.isFavorite.toggle()
        entry.updatedAt = Date()
        try modelContext.save()
    }

    func delete(_ entry: PasswordEntry) throws {
        modelContext.delete(entry)
        try modelContext.save()
    }

    func markUsed(_ entry: PasswordEntry) throws {
        entry.lastUsedAt = Date()
        try modelContext.save()
    }

    func copyPassword(_ entry: PasswordEntry) throws -> String {
        let password = try decryptPassword(entry)
        ClipboardService.copySecret(password)
        try markUsed(entry)
        return password
    }

    func allEntries() throws -> [PasswordEntry] {
        let descriptor = FetchDescriptor<PasswordEntry>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func deleteAllEntries() throws {
        for entry in try allEntries() {
            modelContext.delete(entry)
        }
        try modelContext.save()
    }

    func resetAllLocalData() throws {
        try deleteAllEntries()
        try session.resetLocalUnlock()
    }

    func importEntries(_ imported: [BackupPayload.Entry], strategy: ImportStrategy = .merge) throws {
        let key = try session.currentDataKey()
        let existing = try allEntries()
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for item in imported {
            let encrypted = try AESGCMCipher.encryptString(item.password, key: key)
            if let current = existingByID[item.id] {
                if strategy == .skipExisting { continue }
                current.title = item.title
                current.username = item.username
                current.encryptedPassword = encrypted
                current.url = item.url
                current.notes = item.notes
                current.isFavorite = item.isFavorite
                current.category = item.category
                current.createdAt = item.createdAt
                current.updatedAt = item.updatedAt
            } else {
                modelContext.insert(
                    PasswordEntry(
                        id: item.id,
                        title: item.title,
                        username: item.username,
                        encryptedPassword: encrypted,
                        url: item.url,
                        notes: item.notes,
                        isFavorite: item.isFavorite,
                        category: item.category,
                        createdAt: item.createdAt,
                        updatedAt: item.updatedAt
                    )
                )
            }
        }
        try modelContext.save()
    }

    private static func normalizedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum ImportStrategy {
    case merge
    case skipExisting
}
