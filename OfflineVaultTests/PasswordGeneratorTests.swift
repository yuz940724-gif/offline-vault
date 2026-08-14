import XCTest
@testable import OfflineVault

final class PasswordGeneratorTests: XCTestCase {
    func testLengthAndCharacterClasses() throws {
        var options = PasswordGeneratorOptions()
        options.length = 24
        options.uppercase = true
        options.lowercase = true
        options.digits = true
        options.symbols = true
        options.excludeAmbiguous = true

        let password = try PasswordGenerator.generate(options)
        XCTAssertEqual(password.count, 24)
        XCTAssertTrue(password.contains(where: \.isUppercase))
        XCTAssertTrue(password.contains(where: \.isLowercase))
        XCTAssertTrue(password.contains(where: \.isNumber))
        XCTAssertTrue(password.contains(where: { !$0.isLetter && !$0.isNumber }))
        XCTAssertFalse(password.contains { "0Ol1I|".contains($0) })
    }

    func testRejectsEmptyAlphabet() {
        var options = PasswordGeneratorOptions()
        options.uppercase = false
        options.lowercase = false
        options.digits = false
        options.symbols = false
        XCTAssertThrowsError(try PasswordGenerator.generate(options))
    }

    func testSuccessivePasswordsDiffer() throws {
        let first = try PasswordGenerator.generate(PasswordGeneratorOptions())
        let second = try PasswordGenerator.generate(PasswordGeneratorOptions())
        XCTAssertNotEqual(first, second)
    }
}
