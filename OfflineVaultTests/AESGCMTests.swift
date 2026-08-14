import CryptoKit
import XCTest
@testable import OfflineVault

final class AESGCMTests: XCTestCase {
    func testRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("hunter2-secret".utf8)
        let sealed = try AESGCMCipher.encrypt(plaintext, key: key)
        XCTAssertNotEqual(sealed, plaintext)
        XCTAssertGreaterThan(sealed.count, plaintext.count)
        XCTAssertEqual(try AESGCMCipher.decrypt(sealed, key: key), plaintext)
    }

    func testDifferentNonces() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("same-plain".utf8)
        let first = try AESGCMCipher.encrypt(plaintext, key: key)
        let second = try AESGCMCipher.encrypt(plaintext, key: key)
        XCTAssertNotEqual(first, second)
    }

    func testWrongKeyFails() throws {
        let sealed = try AESGCMCipher.encrypt(Data("secret".utf8), key: SymmetricKey(size: .bits256))
        XCTAssertThrowsError(try AESGCMCipher.decrypt(sealed, key: SymmetricKey(size: .bits256)))
    }

    func testTruncatedCiphertextFails() {
        XCTAssertThrowsError(try AESGCMCipher.decrypt(Data([1, 2, 3]), key: SymmetricKey(size: .bits256)))
    }

    func testStringRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let sealed = try AESGCMCipher.encryptString("主密码测试", key: key)
        XCTAssertEqual(try AESGCMCipher.decryptString(sealed, key: key), "主密码测试")
    }
}
