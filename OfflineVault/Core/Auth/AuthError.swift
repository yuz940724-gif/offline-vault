import Foundation

enum AuthError: Error, Equatable, LocalizedError {
    case vaultNotInitialized
    case alreadyInitialized
    case locked
    case incorrectPassword
    case biometricsUnavailable
    case biometricsNotEnabled
    case biometricsFailed
    case passwordTooWeak
    case passwordMismatch
    case configurationCorrupted
    case keychainFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .vaultNotInitialized:
            return "尚未创建保险库"
        case .alreadyInitialized:
            return "保险库已经存在"
        case .locked:
            return "保险库已锁定"
        case .incorrectPassword:
            return "主密码不正确"
        case .biometricsUnavailable:
            return "此设备不支持生物识别，或尚未录入"
        case .biometricsNotEnabled:
            return "尚未开启生物识别解锁"
        case .biometricsFailed:
            return "生物识别失败，请改用主密码"
        case .passwordTooWeak:
            return "主密码强度不足，请使用更长或更复杂的密码"
        case .passwordMismatch:
            return "两次输入的密码不一致"
        case .configurationCorrupted:
            return "保险库配置损坏"
        case .keychainFailed(let status):
            return "钥匙串访问失败（\(status)）"
        }
    }
}
