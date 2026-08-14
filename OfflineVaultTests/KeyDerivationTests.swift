import XCTest
@testable import OfflineVault

final class KeyDerivationTests: XCTestCase {
    func testArgon2idIsDeterministic() throws {
        var parameters = try KeyDerivationParameters.makeTestParameters(algorithm: .argon2id)
        parameters.salt = Data(repeating: 0x5A, count: 16)
        let first = try KeyDerivation.derive(password: "correct horse battery staple", parameters: parameters)
        let second = try KeyDerivation.derive(password: "correct horse battery staple", parameters: parameters)
        XCTAssertEqual(KeyDerivation.keyData(first), KeyDerivation.keyData(second))
    }

    func testArgon2idChangesWithPassword() throws {
        var parameters = try KeyDerivationParameters.makeTestParameters(algorithm: .argon2id)
        parameters.salt = Data(repeating: 0x11, count: 16)
        let first = try KeyDerivation.derive(password: "alpha-password-1", parameters: parameters)
        let second = try KeyDerivation.derive(password: "alpha-password-2", parameters: parameters)
        XCTAssertNotEqual(KeyDerivation.keyData(first), KeyDerivation.keyData(second))
    }

    func testPBKDF2KnownVector() throws {
        let parameters = KeyDerivationParameters(
            algorithm: .pbkdf2SHA256,
            salt: Data("salt".utf8),
            iterations: 1,
            memoryKiB: 0,
            parallelism: 1,
            outputLength: 32
        )
        let key = try KeyDerivation.derive(password: "password", parameters: parameters)
        XCTAssertEqual(
            KeyDerivation.keyData(key),
            Data(hex: "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b")
        )
    }

    func testVerifierAcceptsCorrectPassword() throws {
        var parameters = try KeyDerivationParameters.makeTestParameters(algorithm: .argon2id)
        parameters.salt = Data(repeating: 0x42, count: 16)
        let password = "FairPassword12"
        let key = try KeyDerivation.derive(password: password, parameters: parameters)
        let verifier = try AESGCMCipher.encryptString(VaultConfiguration.verifierPlaintext, key: key)
        let config = VaultConfiguration(version: 1, parameters: parameters, verifier: verifier, createdAt: Date())
        XCTAssertNoThrow(try config.verify(key))
    }
}

private extension Data {
    init(hex: String) {
        var value = hex
        if value.count % 2 != 0 { value = "0" + value }
        var data = Data()
        var index = value.startIndex
        while index < value.endIndex {
            let next = value.index(index, offsetBy: 2)
            data.append(UInt8(value[index..<next], radix: 16)!)
            index = next
        }
        self = data
    }
}
