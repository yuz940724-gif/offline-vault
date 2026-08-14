import SwiftUI

struct StrengthMeter: View {
    let password: String

    private var strength: PasswordStrength {
        PasswordStrengthEvaluator.evaluate(password)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("密码强度")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(password.isEmpty ? "—" : strength.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("密码强度")
        .accessibilityValue(password.isEmpty ? "未输入" : strength.title)
    }

    private var progress: CGFloat {
        guard !password.isEmpty else { return 0 }
        switch strength {
        case .tooShort: return 0.15
        case .weak: return 0.35
        case .fair: return 0.55
        case .strong: return 0.78
        case .veryStrong: return 1
        }
    }

    private var color: Color {
        if password.isEmpty { return .secondary }
        switch strength {
        case .tooShort, .weak: return .red
        case .fair: return .orange
        case .strong: return .green
        case .veryStrong: return .teal
        }
    }
}
