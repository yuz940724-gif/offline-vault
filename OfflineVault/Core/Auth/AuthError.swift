import Foundation

enum AuthError: Error, Equatable, LocalizedError {
    case vaultNotInitialized
    case alreadyInitialized
    case locked
    case incorrectPassword
    case biometricsUnavailable
    case biometricsFailed
    case passwordTooWeak
    case passwordMismatch
    case configurationCorrupted
    case keychainFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .vaultNotInitialized:
            return "还没有在这台 iPhone 上创建密码本"
        case .alreadyInitialized:
            return "这台 iPhone 上已经有密码本"
        case .locked:
            return "已锁定"
        case .incorrectPassword:
            return "密码不正确"
        case .biometricsUnavailable:
            return "请先在系统设置里开启面容 ID，或设置设备密码"
        case .biometricsFailed:
            return "未能解锁，请再试一次"
        case .passwordTooWeak:
            return "密码强度不足"
        case .passwordMismatch:
            return "两次输入的密码不一致"
        case .configurationCorrupted:
            return "本地数据无法读取"
        case .keychainFailed(let status):
            return "无法访问本机钥匙串（\(status)）"
        }
    }
}
