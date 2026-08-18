import Foundation
import SwiftData

enum VaultError: LocalizedError, Equatable {
    case invalidGroup
    case duplicateGroup

    var errorDescription: String? {
        switch self {
        case .invalidGroup:
            return "请输入一级分组名称"
        case .duplicateGroup:
            return "这个分组已经存在"
        }
    }
}

@MainActor
@Observable
final class VaultService {
    private struct GroupKey: Hashable {
        let category: String?
    }

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
        let now = Date()
        let normalizedCategory = Self.normalizedOptional(category)
        let entry = PasswordEntry(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            encryptedPassword: try AESGCMCipher.encryptString(password, key: key),
            url: Self.normalizedOptional(url),
            notes: Self.normalizedOptional(notes),
            isFavorite: isFavorite,
            category: normalizedCategory,
            // Secondary groups remain only as a legacy storage field. New
            // entries are always assigned to one category.
            subcategory: nil,
            sortOrder: try nextSortOrder(category: normalizedCategory),
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
        let normalizedCategory = Self.normalizedOptional(category)
        let groupChanged = entry.category != normalizedCategory

        entry.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.encryptedPassword = try AESGCMCipher.encryptString(password, key: key)
        entry.url = Self.normalizedOptional(url)
        entry.notes = Self.normalizedOptional(notes)
        entry.category = normalizedCategory
        entry.subcategory = nil
        if groupChanged {
            entry.sortOrder = try nextSortOrder(category: normalizedCategory)
        }
        entry.isFavorite = isFavorite
        entry.updatedAt = Date()
        try modelContext.save()
    }

    func moveEntry(
        entryID: UUID,
        toCategory rawCategory: String?,
        before beforeEntryID: UUID?
    ) throws {
        let all = try allEntries()
        guard let dragged = all.first(where: { $0.id == entryID }) else { return }

        let sourceKey = GroupKey(
            category: Self.normalizedOptional(dragged.category)
        )
        let targetKey = GroupKey(
            category: Self.normalizedOptional(rawCategory)
        )

        if sourceKey == targetKey && beforeEntryID == dragged.id {
            return
        }

        var targetEntries = entries(in: targetKey, from: all)
            .filter { $0.id != dragged.id }
            .sorted(by: compareForSortOrder)

        if let beforeEntryID,
           let index = targetEntries.firstIndex(where: { $0.id == beforeEntryID }) {
            targetEntries.insert(dragged, at: index)
        } else {
            targetEntries.append(dragged)
        }

        dragged.category = targetKey.category
        dragged.subcategory = nil
        dragged.updatedAt = Date()

        for (index, entry) in targetEntries.enumerated() {
            entry.sortOrder = index
        }

        if sourceKey != targetKey {
            let sourceEntries = entries(in: sourceKey, from: all)
                .filter { $0.id != dragged.id }
                .sorted(by: compareForSortOrder)
            for (index, entry) in sourceEntries.enumerated() {
                entry.sortOrder = index
            }
        }

        try normalizeSortOrder(in: [sourceKey, targetKey])
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
            sortBy: [
                SortDescriptor(\.category),
                SortDescriptor(\.sortOrder),
                SortDescriptor(\.updatedAt, order: .reverse)
            ]
        )
        return try modelContext.fetch(descriptor)
    }

    func allGroups() throws -> [PasswordGroup] {
        let descriptor = FetchDescriptor<PasswordGroup>(
            sortBy: [
                SortDescriptor(\.category),
                SortDescriptor(\.updatedAt, order: .reverse)
            ]
        )
        return try modelContext.fetch(descriptor)
    }

    func ensureGroupsFromEntries() throws {
        let entries = try allEntries()
        let existing = try allGroups()
        var existingCategories = Set<String>()
        var didChange = false

        // Flatten data created by the removed secondary-group feature without
        // touching encrypted passwords or deleting any password entry.
        for entry in entries where entry.subcategory != nil {
            entry.subcategory = nil
            didChange = true
        }

        for group in existing {
            guard let category = Self.normalizedOptional(group.category) else {
                modelContext.delete(group)
                didChange = true
                continue
            }
            if group.category != category {
                group.category = category
                didChange = true
            }
            if group.subcategory != nil {
                group.subcategory = nil
                didChange = true
            }
            if !existingCategories.insert(category).inserted {
                modelContext.delete(group)
                didChange = true
            }
        }

        for entry in entries {
            guard let category = Self.normalizedOptional(entry.category),
                  existingCategories.insert(category).inserted else { continue }
            modelContext.insert(PasswordGroup(category: category))
            didChange = true
        }

        if didChange {
            try modelContext.save()
        }
    }

    func createGroup(category: String) throws {
        guard let category = Self.normalizedOptional(category) else {
            throw VaultError.invalidGroup
        }
        let existing = try allGroups()
        guard !existing.contains(where: {
            Self.normalizedOptional($0.category) == category
        }) else {
            throw VaultError.duplicateGroup
        }
        modelContext.insert(PasswordGroup(category: category))
        try modelContext.save()
    }

    func deleteGroup(category: String) throws {
        let normalizedCategory = Self.normalizedOptional(category)
        for group in try allGroups()
        where Self.normalizedOptional(group.category) == normalizedCategory {
            modelContext.delete(group)
        }
        try modelContext.save()
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

#if targetEnvironment(simulator)
    func resetForSimulatorBypass() throws {
        try deleteAllEntries()
        try session.resetLocalUnlock()
        try session.enableSimulatorBypass()
    }
#endif

    func importEntries(_ imported: [BackupPayload.Entry], strategy: ImportStrategy = .merge) throws {
        let key = try session.currentDataKey()
        let existing = try allEntries()
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        var touchedGroup: Set<GroupKey> = []

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
                current.category = Self.normalizedOptional(item.category)
                current.subcategory = nil
                current.createdAt = item.createdAt
                current.updatedAt = item.updatedAt
                current.sortOrder = item.sortOrder
                touchedGroup.insert(GroupKey(category: Self.normalizedOptional(item.category)))
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
                        category: Self.normalizedOptional(item.category),
                        subcategory: nil,
                        sortOrder: item.sortOrder,
                        createdAt: item.createdAt,
                        updatedAt: item.updatedAt
                    )
                )
                touchedGroup.insert(GroupKey(category: Self.normalizedOptional(item.category)))
            }
        }

        try normalizeSortOrder(in: touchedGroup)
        try modelContext.save()
    }

    private static func normalizedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func nextSortOrder(category: String?) throws -> Int {
        let allEntries = try allEntries()
        let key = GroupKey(category: category)
        let values = entries(in: key, from: allEntries)
        if values.isEmpty {
            return 0
        }
        return (values.map { $0.sortOrder }.max() ?? -1) + 1
    }

    private func entries(in key: GroupKey, from all: [PasswordEntry]) -> [PasswordEntry] {
        all.filter {
            GroupKey(category: Self.normalizedOptional($0.category)) == key
        }
    }

    private func compareForSortOrder(_ lhs: PasswordEntry, _ rhs: PasswordEntry) -> Bool {
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        let lhsUpdated = lhs.lastUsedAt ?? lhs.updatedAt
        let rhsUpdated = rhs.lastUsedAt ?? rhs.updatedAt
        return lhsUpdated > rhsUpdated
    }

    private func normalizeSortOrder(in groups: Set<GroupKey>) throws {
        let allEntries = try allEntries()
        for group in groups {
            let sorted = entries(in: group, from: allEntries)
                .sorted(by: compareForSortOrder)
            for (index, entry) in sorted.enumerated() {
                entry.sortOrder = index
            }
        }
    }
}

enum ImportStrategy {
    case merge
    case skipExisting
}
