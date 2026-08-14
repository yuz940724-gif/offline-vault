import CryptoKit
import Foundation

enum AppPasswordStore {
    private static var fileURL: URL {
        Persistence.vaultDirectory().appending(path: "app-password.json")
    }

    struct Record: Codable, Equatable {
        var parameters: KeyDerivationParameters
        var wrappedKey: Data
    }

    static func exists() -> Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    static func wrap(key: SymmetricKey, password: String) throws {
        let parameters = try KeyDerivationParameters.makeDefault(algorithm: .argon2id)
        let wrappingKey = try KeyDerivation.derive(password: password, parameters: parameters)
        var raw = KeyDerivation.keyData(key)
        defer { SecureMemory.zero(&raw) }
        let wrapped = try AESGCMCipher.encrypt(raw, key: wrappingKey)
        let record = Record(parameters: parameters, wrappedKey: wrapped)
        let data = try JSONEncoder().encode(record)
        try data.write(to: fileURL, options: [.atomic])
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: fileURL.path
        )
    }

    static func unwrap(password: String) throws -> SymmetricKey {
        guard exists() else { throw AuthError.vaultNotInitialized }
        let record = try JSONDecoder().decode(Record.self, from: Data(contentsOf: fileURL))
        let wrappingKey = try KeyDerivation.derive(password: password, parameters: record.parameters)
        do {
            var raw = try AESGCMCipher.decrypt(record.wrappedKey, key: wrappingKey)
            defer { SecureMemory.zero(&raw) }
            return SymmetricKey(data: raw)
        } catch {
            throw AuthError.incorrectPassword
        }
    }

    static func delete() throws {
        guard exists() else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
