import CryptoKit
import Foundation
import LocalAuthentication
import Security

enum KeychainStore {
    private static let service = "com.offlinevault.dek"
    private static let biometricAccount = "data-encryption-key"
    private static let openAccount = "data-encryption-key-open"

    static func saveBiometricKey(_ key: SymmetricKey) throws {
        try save(key, account: biometricAccount, requirePresence: true)
    }

    static func loadBiometricKey(context: LAContext) throws -> SymmetricKey {
        try load(account: biometricAccount, context: context)
    }

    static func biometricExists() -> Bool {
        exists(account: biometricAccount)
    }

    static func deleteBiometricKey() throws {
        try delete(account: biometricAccount)
    }

    static func saveOpenKey(_ key: SymmetricKey) throws {
        try save(key, account: openAccount, requirePresence: false)
    }

    static func loadOpenKey() throws -> SymmetricKey {
        try load(account: openAccount, context: nil)
    }

    static func openExists() -> Bool {
        exists(account: openAccount)
    }

    static func deleteOpenKey() throws {
        try delete(account: openAccount)
    }

    static func deleteAll() throws {
        try deleteBiometricKey()
        try deleteOpenKey()
    }

    private static func save(_ key: SymmetricKey, account: String, requirePresence: Bool) throws {
        var keyData = KeyDerivation.keyData(key)
        defer { SecureMemory.zero(&keyData) }
        try delete(account: account)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData
        ]

        if requirePresence {
            var createError: Unmanaged<CFError>?
            guard let access = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .userPresence,
                &createError
            ) else {
                throw AuthError.keychainFailed(errSecParam)
            }
            query[kSecAttrAccessControl as String] = access
        } else {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AuthError.keychainFailed(status)
        }
    }

    private static func load(account: String, context: LAContext?) throws -> SymmetricKey {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let context {
            query[kSecUseAuthenticationContext as String] = context
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, var data = item as? Data else {
            if status == errSecItemNotFound {
                throw AuthError.vaultNotInitialized
            }
            if status == errSecUserCanceled || status == errSecAuthFailed {
                throw AuthError.biometricsFailed
            }
            if status == errSecInteractionNotAllowed {
                throw AuthError.biometricsTemporarilyUnavailable
            }
            throw AuthError.keychainFailed(status)
        }
        defer { SecureMemory.zero(&data) }
        return SymmetricKey(data: data)
    }

    private static func exists(account: String) -> Bool {
        let context = LAContext()
        context.interactionNotAllowed = true
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false,
            kSecUseAuthenticationContext as String: context
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    private static func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthError.keychainFailed(status)
        }
    }
}
