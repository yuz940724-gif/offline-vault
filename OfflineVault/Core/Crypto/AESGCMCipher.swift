import CryptoKit
import Foundation

enum AESGCMCipher {
    static let keyByteCount = 32

    static func encrypt(_ plaintext: Data, key: SymmetricKey) throws -> Data {
        do {
            let sealed = try AES.GCM.seal(plaintext, using: key)
            guard let combined = sealed.combined else {
                throw CryptoError.encryptionFailed
            }
            return combined
        } catch let error as CryptoError {
            throw error
        } catch {
            throw CryptoError.encryptionFailed
        }
    }

    static func encryptString(_ string: String, key: SymmetricKey) throws -> Data {
        try SecureMemory.withSecureUTF8(string) { data in
            try encrypt(data, key: key)
        }
    }

    static func decrypt(_ combined: Data, key: SymmetricKey) throws -> Data {
        guard combined.count >= 12 + 16 else {
            throw CryptoError.invalidCiphertext
        }
        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(box, using: key)
        } catch let error as CryptoError {
            throw error
        } catch {
            throw CryptoError.decryptionFailed
        }
    }

    static func decryptString(_ combined: Data, key: SymmetricKey) throws -> String {
        var plaintext = try decrypt(combined, key: key)
        defer { SecureMemory.zero(&plaintext) }
        guard let string = String(data: plaintext, encoding: .utf8) else {
            throw CryptoError.encodingFailed
        }
        return string
    }
}
