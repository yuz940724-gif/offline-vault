import CryptoKit
import Foundation

struct VaultConfiguration: Codable, Equatable, Sendable {
    static let currentVersion = 1
    static let verifierPlaintext = "offline-vault.verifier.v1"

    var version: Int
    var parameters: KeyDerivationParameters
    var verifier: Data
    var createdAt: Date

    static func create(masterPassword: String, algorithm: KeyDerivationAlgorithm = .argon2id) throws -> (VaultConfiguration, SymmetricKey) {
        let parameters = try KeyDerivationParameters.makeDefault(algorithm: algorithm)
        let key = try KeyDerivation.derive(password: masterPassword, parameters: parameters)
        let verifier = try AESGCMCipher.encryptString(verifierPlaintext, key: key)
        let config = VaultConfiguration(
            version: currentVersion,
            parameters: parameters,
            verifier: verifier,
            createdAt: Date()
        )
        return (config, key)
    }

    func verify(_ key: SymmetricKey) throws {
        let plaintext = try AESGCMCipher.decryptString(verifier, key: key)
        guard plaintext == Self.verifierPlaintext else {
            throw AuthError.incorrectPassword
        }
    }

    func replacingKey(from currentPassword: String, to newPassword: String) throws -> (VaultConfiguration, SymmetricKey) {
        let currentKey = try KeyDerivation.derive(password: currentPassword, parameters: parameters)
        do {
            try verify(currentKey)
        } catch {
            throw AuthError.incorrectPassword
        }
        return try VaultConfiguration.create(masterPassword: newPassword, algorithm: parameters.algorithm)
    }
}

enum VaultConfigurationStore {
    static var fileURL: URL {
        Persistence.vaultDirectory().appending(path: "vault-config.json")
    }

    static func exists() -> Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    static func load() throws -> VaultConfiguration {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AuthError.vaultNotInitialized
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(VaultConfiguration.self, from: data)
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.configurationCorrupted
        }
    }

    static func save(_ configuration: VaultConfiguration) throws {
        let url = fileURL
        let data = try JSONEncoder().encode(configuration)
        try data.write(to: url, options: [.atomic])
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
    }
}
