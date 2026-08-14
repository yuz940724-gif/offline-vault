import Foundation
import LocalAuthentication

enum BiometricKind: Equatable, Sendable {
    case none
    case faceID
    case touchID
    case opticID

    var title: String {
        switch self {
        case .none: return "生物识别"
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
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
}

enum BiometricUnlock {
    static func availableKind() -> BiometricKind {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .opticID
        default:
            return .none
        }
    }

    static func makeContext(reason: String) -> LAContext {
        let context = LAContext()
        context.localizedReason = reason
        context.localizedCancelTitle = "改用主密码"
        context.touchIDAuthenticationAllowableReuseDuration = 0
        return context
    }
}
