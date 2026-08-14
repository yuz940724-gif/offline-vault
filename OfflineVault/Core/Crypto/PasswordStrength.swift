import Foundation

enum PasswordStrength: Int, Comparable, Sendable {
    case tooShort
    case weak
    case fair
    case strong
    case veryStrong

    static func < (lhs: PasswordStrength, rhs: PasswordStrength) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .tooShort: return "过短"
        case .weak: return "弱"
        case .fair: return "一般"
        case .strong: return "强"
        case .veryStrong: return "很强"
        }
    }

    var isAcceptableForMasterPassword: Bool {
        self >= .fair
    }
}

enum PasswordStrengthEvaluator {
    static let minimumMasterPasswordLength = 8

    private static let commonPasswords: Set<String> = [
        "password", "password1", "12345678", "123456789", "1234567890",
        "qwerty123", "iloveyou", "admin123", "welcome1", "letmein",
        "11111111", "00000000", "passw0rd", "abc12345", "monkey123",
        "password123", "qwertyuiop", "1q2w3e4r", "zaq12wsx"
    ]

    static func evaluate(_ password: String) -> PasswordStrength {
        let length = password.count
        if length < minimumMasterPasswordLength {
            return .tooShort
        }

        if commonPasswords.contains(password.lowercased()) {
            return .weak
        }

        let classes = characterClassCount(password)
        if length >= 16 && classes >= 4 {
            return .veryStrong
        }
        if length >= 12 && classes >= 3 {
            return .strong
        }
        if (length >= 12 && classes >= 2) || (length >= 10 && classes >= 3) {
            return .fair
        }
        return .weak
    }

    static func characterClassCount(_ password: String) -> Int {
        var count = 0
        if password.contains(where: { $0.isLowercase }) { count += 1 }
        if password.contains(where: { $0.isUppercase }) { count += 1 }
        if password.contains(where: { $0.isNumber }) { count += 1 }
        if password.contains(where: { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }) {
            count += 1
        }
        return count
    }
}
