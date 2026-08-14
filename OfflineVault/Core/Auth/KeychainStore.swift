import CryptoKit
import Foundation
import LocalAuthentication
import Security

enum KeychainStore {
    private static let service = "com.offlinevault.dek"
    private static let account = "data-encryption-key"

    static func saveProtectedKey(_ key: SymmetricKey) throws {
        var keyData = KeyDerivation.keyData(key)
        defer { SecureMemory.zero(&keyData) }

        var createError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &createError
        ) else {
            throw AuthError.keychainFailed(errSecParam)
        }

        try? delete()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessControl as String: access
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AuthError.keychainFailed(status)
        }
    }

    static func loadProtectedKey(context: LAContext) throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, var data = item as? Data else {
            if status == errSecItemNotFound {
                throw AuthError.biometricsNotEnabled
            }
            if status == errSecUserCanceled || status == errSecAuthFailed {
                throw AuthError.biometricsFailed
            }
            throw AuthError.keychainFailed(status)
        }
        defer { SecureMemory.zero(&data) }
        return SymmetricKey(data: data)
    }

    static func exists() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    static func delete() throws {
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
