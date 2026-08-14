import CommonCrypto
import CryptoKit
import Foundation

enum KeyDerivationAlgorithm: String, Codable, CaseIterable, Sendable {
    case argon2id
    case pbkdf2SHA256 = "pbkdf2-sha256"
}

struct KeyDerivationParameters: Codable, Equatable, Sendable {
    var algorithm: KeyDerivationAlgorithm
    var salt: Data
    var iterations: Int
    var memoryKiB: Int
    var parallelism: Int
    var outputLength: Int

    static func makeDefault(algorithm: KeyDerivationAlgorithm = .argon2id) throws -> KeyDerivationParameters {
        switch algorithm {
        case .argon2id:
            return KeyDerivationParameters(
                algorithm: .argon2id,
                salt: try SecureMemory.randomBytes(count: 16),
                iterations: 3,
                memoryKiB: 32 * 1024,
                parallelism: 1,
                outputLength: AESGCMCipher.keyByteCount
            )
        case .pbkdf2SHA256:
            return KeyDerivationParameters(
                algorithm: .pbkdf2SHA256,
                salt: try SecureMemory.randomBytes(count: 16),
                iterations: 600_000,
                memoryKiB: 0,
                parallelism: 1,
                outputLength: AESGCMCipher.keyByteCount
            )
        }
    }

    /// Lightweight parameters reserved for unit tests.
    static func makeTestParameters(algorithm: KeyDerivationAlgorithm) throws -> KeyDerivationParameters {
        switch algorithm {
        case .argon2id:
            return KeyDerivationParameters(
                algorithm: .argon2id,
                salt: try SecureMemory.randomBytes(count: 16),
                iterations: 2,
                memoryKiB: 16,
                parallelism: 1,
                outputLength: AESGCMCipher.keyByteCount
            )
        case .pbkdf2SHA256:
            return KeyDerivationParameters(
                algorithm: .pbkdf2SHA256,
                salt: try SecureMemory.randomBytes(count: 16),
                iterations: 1_000,
                memoryKiB: 0,
                parallelism: 1,
                outputLength: AESGCMCipher.keyByteCount
            )
        }
    }
}

enum KeyDerivation {
    static func derive(password: String, parameters: KeyDerivationParameters) throws -> SymmetricKey {
        try SecureMemory.withSecureUTF8(password) { passwordData in
            try derive(password: passwordData, parameters: parameters)
        }
    }

    static func derive(password: Data, parameters: KeyDerivationParameters) throws -> SymmetricKey {
        guard parameters.outputLength > 0, !parameters.salt.isEmpty else {
            throw CryptoError.invalidParameters
        }

        var raw: Data
        switch parameters.algorithm {
        case .argon2id:
            raw = try argon2id(password: password, parameters: parameters)
        case .pbkdf2SHA256:
            raw = try pbkdf2SHA256(password: password, parameters: parameters)
        }
        defer { SecureMemory.zero(&raw) }
        return SymmetricKey(data: raw)
    }

    static func keyData(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }

    private static func argon2id(password: Data, parameters: KeyDerivationParameters) throws -> Data {
        guard parameters.iterations > 0,
              parameters.memoryKiB >= 8,
              parameters.parallelism > 0
        else {
            throw CryptoError.invalidParameters
        }

        var output = Data(count: parameters.outputLength)
        let status = output.withUnsafeMutableBytes { outPtr in
            password.withUnsafeBytes { passPtr in
                parameters.salt.withUnsafeBytes { saltPtr in
                    argon2id_hash_raw(
                        UInt32(parameters.iterations),
                        UInt32(parameters.memoryKiB),
                        UInt32(parameters.parallelism),
                        passPtr.baseAddress,
                        password.count,
                        saltPtr.baseAddress,
                        parameters.salt.count,
                        outPtr.baseAddress,
                        parameters.outputLength
                    )
                }
            }
        }

        guard status == ARGON2_OK.rawValue else {
            SecureMemory.zero(&output)
            throw CryptoError.derivationFailed(status)
        }
        return output
    }

    private static func pbkdf2SHA256(password: Data, parameters: KeyDerivationParameters) throws -> Data {
        guard parameters.iterations > 0 else {
            throw CryptoError.invalidParameters
        }

        var output = Data(count: parameters.outputLength)
        let status = output.withUnsafeMutableBytes { outPtr in
            password.withUnsafeBytes { passPtr in
                parameters.salt.withUnsafeBytes { saltPtr in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passPtr.bindMemory(to: Int8.self).baseAddress,
                        password.count,
                        saltPtr.bindMemory(to: UInt8.self).baseAddress,
                        parameters.salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(parameters.iterations),
                        outPtr.bindMemory(to: UInt8.self).baseAddress,
                        parameters.outputLength
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            SecureMemory.zero(&output)
            throw CryptoError.derivationFailed(status)
        }
        return output
    }
}
