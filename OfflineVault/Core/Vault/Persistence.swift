import Foundation
import SwiftData

enum Persistence {
    static func makeContainer() throws -> ModelContainer {
        let directory = vaultDirectory()
        let url = directory.appending(path: "Vault.store")
        do {
            // The previous development build wrote this same model directly
            // with SwiftData's implicit 1.0 schema. Open that store first so
            // it is not reported as an unknown staged-migration version.
            let currentSchema = Schema([PasswordEntry.self, PasswordGroup.self])
            let currentConfiguration = ModelConfiguration(
                "OfflineVault",
                schema: currentSchema,
                url: url,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: currentSchema,
                configurations: [currentConfiguration]
            )
            applyFileProtection(in: directory)
            return container
        } catch {
            // Devices that still have the original one-model store use the
            // explicit V1 -> V2 plan below.
            let versionedSchema = Schema(versionedSchema: OfflineVaultSchemaV2.self)
            let versionedConfiguration = ModelConfiguration(
                "OfflineVault",
                schema: versionedSchema,
                url: url,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: versionedSchema,
                migrationPlan: OfflineVaultMigrationPlan.self,
                configurations: [versionedConfiguration]
            )
            applyFileProtection(in: directory)
            return container
        }
    }

    static func vaultDirectory() -> URL {
        let fileManager = FileManager.default
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory = support.appending(path: "OfflineVault", directoryHint: .isDirectory)

        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
        } else {
            try? fileManager.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: directory.path
            )
        }

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = directory
        try? mutable.setResourceValues(values)
        return directory
    }

    private static func applyFileProtection(in directory: URL) {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return
        }
        for case let fileURL as URL in enumerator {
            try? fileManager.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: fileURL.path
            )
        }
    }
}

/// The first shipped schema contained only PasswordEntry. Keep a local copy
/// of that model so an existing device store can be migrated in place.
enum OfflineVaultSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [PasswordEntry.self]
    }

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
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.lastUsedAt = lastUsedAt
        }
    }
}

enum OfflineVaultSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [PasswordEntry.self, PasswordGroup.self]
    }
}

enum OfflineVaultMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [OfflineVaultSchemaV1.self, OfflineVaultSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: OfflineVaultSchemaV1.self,
                toVersion: OfflineVaultSchemaV2.self
            )
        ]
    }
}
