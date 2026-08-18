import XCTest
@testable import OfflineVault

final class BackupServiceTests: XCTestCase {
    func testExportImportRoundTrip() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = PasswordEntry(
            title: "GitHub",
            username: "ada",
            encryptedPassword: Data("not-used".utf8),
            url: "https://github.com",
            notes: "personal",
            isFavorite: true,
            category: "dev",
            subcategory: "source-control",
            createdAt: now,
            updatedAt: now
        )
        let parameters = try KeyDerivationParameters.makeTestParameters(algorithm: .argon2id)
        let file = try BackupService.export(
            entries: [entry],
            decryptPassword: { _ in "s3cret!" },
            password: "BackupPassphrase12",
            parameters: parameters
        )

        XCTAssertTrue(file.starts(with: BackupService.magic))

        let payload = try BackupService.importData(file, password: "BackupPassphrase12")
        XCTAssertEqual(payload.entries.count, 1)
        XCTAssertEqual(payload.entries[0].title, "GitHub")
        XCTAssertEqual(payload.entries[0].password, "s3cret!")
        XCTAssertEqual(payload.entries[0].username, "ada")
        XCTAssertTrue(payload.entries[0].isFavorite)
        XCTAssertNil(payload.entries[0].subcategory)
    }

    func testWrongBackupPasswordFails() throws {
        let entry = PasswordEntry(
            title: "Mail",
            username: "root",
            encryptedPassword: Data(),
            createdAt: Date(),
            updatedAt: Date()
        )
        let file = try BackupService.export(
            entries: [entry],
            decryptPassword: { _ in "hidden" },
            password: "BackupPassphrase12",
            parameters: try KeyDerivationParameters.makeTestParameters(algorithm: .argon2id)
        )
        XCTAssertThrowsError(try BackupService.importData(file, password: "WrongPassphrase12")) { error in
            XCTAssertEqual(error as? BackupError, .incorrectPassword)
        }
    }

    func testInvalidMagicFails() {
        XCTAssertThrowsError(try BackupService.parse(Data("XXXX".utf8)))
    }
}
