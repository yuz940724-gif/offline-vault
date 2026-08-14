import Foundation
import LocalAuthentication

enum BiometricKind: Equatable, Sendable {
    case none
    case faceID
    case touchID
    case opticID

    var title: String {
        switch self {
        case .none: return "设备密码"
        case .faceID: return "面容 ID"
        case .touchID: return "触控 ID"
        case .opticID: return "Optic ID"
        }
    }

    var systemImage: String {
        switch self {
        case .none: return "lock.fill"
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        }
    }

    var unlockTitle: String {
        "使用\(title)打开"
    }
}

enum BiometricUnlock {
    static let reason = "打开本机密码"

    static func availableKind() -> BiometricKind {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return .none
        }
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                return .faceID
            case .touchID:
                return .touchID
            case .opticID:
                return .opticID
            default:
                break
            }
        }
        return .none
    }

    static func canProtectApp() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    static func makeContext() -> LAContext {
        let context = LAContext()
        context.localizedReason = reason
        context.localizedCancelTitle = "取消"
        context.touchIDAuthenticationAllowableReuseDuration = 0
        return context
    }
}
