import Foundation

enum CryptoError: Error, Equatable, LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case derivationFailed(Int32)
    case invalidParameters
    case randomGenerationFailed
    case invalidCiphertext
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "加密失败"
        case .decryptionFailed:
            return "解密失败，主密码可能不正确"
        case .derivationFailed(let code):
            return "密钥派生失败（\(code)）"
        case .invalidParameters:
            return "密钥派生参数无效"
        case .randomGenerationFailed:
            return "无法生成安全随机数"
        case .invalidCiphertext:
            return "密文格式无效"
        case .encodingFailed:
            return "数据编码失败"
        }
    }
}
