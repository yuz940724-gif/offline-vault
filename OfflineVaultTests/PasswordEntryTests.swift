import XCTest
import SwiftData
@testable import OfflineVault

@MainActor
final class PasswordEntryTests: XCTestCase {
    func testGroupPathAndSearchUseOnlyThePrimaryGroup() {
        let entry = PasswordEntry(
            title: "Console",
            username: "admin",
            encryptedPassword: Data(),
            category: "ECS",
            subcategory: "AppStore"
        )

        XCTAssertEqual(entry.groupPath, "ECS")
        XCTAssertTrue(entry.matches(query: "ECS"))
        XCTAssertFalse(entry.matches(query: "AppStore"))
        XCTAssertTrue(entry.matches(query: "admin"))
        XCTAssertFalse(entry.matches(query: "unknown"))
    }

    func testV1StoreMigratesToV2WithoutLosingEncryptedEntry() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("offline-vault-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("Vault.store")
        let id = UUID()
        try createLegacyStore(at: url, id: id)

        let schema = Schema(versionedSchema: OfflineVaultSchemaV2.self)
        let configuration = ModelConfiguration(
            "OfflineVault",
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: schema,
            migrationPlan: OfflineVaultMigrationPlan.self,
            configurations: [configuration]
        )

        let entries = try container.mainContext.fetch(FetchDescriptor<PasswordEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.id, id)
        XCTAssertEqual(entries.first?.title, "Legacy")
        XCTAssertNil(entries.first?.subcategory)
        XCTAssertEqual(entries.first?.sortOrder, 0)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<PasswordGroup>()).isEmpty)
    }

    private func createLegacyStore(at url: URL, id: UUID) throws {
        let schema = Schema(versionedSchema: OfflineVaultSchemaV1.self)
        let configuration = ModelConfiguration(
            "OfflineVaultLegacy",
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let entry = OfflineVaultSchemaV1.PasswordEntry(
            id: id,
            title: "Legacy",
            username: "old-user",
            encryptedPassword: Data("ciphertext".utf8),
            category: "Old Group"
        )
        container.mainContext.insert(entry)
        try container.mainContext.save()
    }
}
