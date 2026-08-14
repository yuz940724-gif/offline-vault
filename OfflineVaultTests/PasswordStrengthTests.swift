import XCTest
@testable import OfflineVault

final class PasswordStrengthTests: XCTestCase {
    func testTooShort() {
        XCTAssertEqual(PasswordStrengthEvaluator.evaluate("Ab1!"), .tooShort)
    }

    func testCommonPasswordIsWeak() {
        XCTAssertEqual(PasswordStrengthEvaluator.evaluate("password1"), .weak)
    }

    func testFairPasswordIsAcceptable() {
        let strength = PasswordStrengthEvaluator.evaluate("FairPass12")
        XCTAssertGreaterThanOrEqual(strength, .fair)
        XCTAssertTrue(strength.isAcceptableForMasterPassword)
    }

    func testVeryStrong() {
        XCTAssertEqual(PasswordStrengthEvaluator.evaluate("VeryStrong Passphrase 42!"), .veryStrong)
    }
}
