import Foundation

enum SecureMemory {
    /// Overwrites the buffer with zeros using `memset_s`, which the compiler
    /// is not allowed to elide.
    static func zero(_ data: inout Data) {
        guard !data.isEmpty else { return }
        data.withUnsafeMutableBytes { pointer in
            guard let base = pointer.baseAddress else { return }
            memset_s(base, pointer.count, 0, pointer.count)
        }
    }

    static func randomBytes(count: Int) throws -> Data {
        precondition(count > 0)
        var bytes = Data(count: count)
        let status = bytes.withUnsafeMutableBytes { pointer -> Int32 in
            guard let base = pointer.bindMemory(to: UInt8.self).baseAddress else {
                return errSecParam
            }
            return SecRandomCopyBytes(kSecRandomDefault, count, base)
        }
        guard status == errSecSuccess else {
            zero(&bytes)
            throw CryptoError.randomGenerationFailed
        }
        return bytes
    }

    static func withSecureUTF8<T>(_ string: String, _ body: (Data) throws -> T) rethrows -> T {
        var data = Data(string.utf8)
        defer { zero(&data) }
        return try body(data)
    }
}
