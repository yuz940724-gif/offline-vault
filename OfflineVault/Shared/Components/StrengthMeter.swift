import SwiftUI

struct StrengthMeter: View {
    let password: String

    private var strength: PasswordStrength {
        PasswordStrengthEvaluator.evaluate(password)
    }

    var body: some View {
        LabeledContent("强度") {
            Text(password.isEmpty ? "—" : strength.title)
                .foregroundStyle(color)
        }
        .accessibilityLabel("密码强度")
        .accessibilityValue(password.isEmpty ? "未输入" : strength.title)
    }

    private var color: Color {
        if password.isEmpty { return .secondary }
        switch strength {
        case .tooShort, .weak:
            return .red
        case .fair:
            return .orange
        case .strong, .veryStrong:
            return .secondary
        }
    }
}
