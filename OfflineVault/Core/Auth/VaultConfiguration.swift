import CryptoKit
import Foundation

struct VaultConfiguration: Codable, Equatable, Sendable {
    static let currentVersion = 1
    static let verifierPlaintext = "offline-vault.verifier.v1"

    var version: Int
    var parameters: KeyDerivationParameters
    var verifier: Data
    var createdAt: Date

    func verify(_ key: SymmetricKey) throws {
        let plaintext = try AESGCMCipher.decryptString(verifier, key: key)
        guard plaintext == Self.verifierPlaintext else {
            throw AuthError.incorrectPassword
        }
    }
}
