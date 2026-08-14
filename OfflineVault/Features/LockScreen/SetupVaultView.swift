import SwiftUI

struct SetupVaultView: View {
    @Environment(SessionController.self) private var session

    @State private var password = ""
    @State private var confirmation = ""
    @State private var enableBiometrics = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var strength: PasswordStrength {
        PasswordStrengthEvaluator.evaluate(password)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    VaultCard {
                        VStack(alignment: .leading, spacing: 16) {
                            SecureField("主密码", text: $password)
                                .textContentType(.none)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            SecureField("再次输入主密码", text: $confirmation)
                                .textContentType(.none)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            StrengthMeter(password: password)
                            if session.biometricKind != .none {
                                Toggle(isOn: $enableBiometrics) {
                                    Label(
                                        "启用\(session.biometricKind.title)解锁",
                                        systemImage: session.biometricKind.systemImage
                                    )
                                }
                            }
                        }
                    }

                    Text("主密码不会被存储，只用于派生加密密钥。忘记后无法恢复数据。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button(action: createVault) {
                        label("创建保险库", systemImage: "lock.shield.fill")
                    }
                    .vaultProminentButton()
                    .disabled(!canCreate || isWorking)
                }
                .padding(24)
            }
            .background(VaultBackdrop())
            .navigationTitle("首次设置")
        }
        .onAppear {
            enableBiometrics = session.biometricKind != .none
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 42))
                .foregroundStyle(.tint)
            Text("创建完全离线的保险库")
                .font(.title2.weight(.semibold))
            Text("数据只保存在这台设备上，不会申请网络权限，也不会同步到 iCloud。")
                .foregroundStyle(.secondary)
        }
    }

    private var canCreate: Bool {
        strength.isAcceptableForMasterPassword && password == confirmation && !password.isEmpty
    }

    private func createVault() {
        errorMessage = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await session.setupMasterPassword(
                    password,
                    confirmation: confirmation,
                    enableBiometrics: enableBiometrics
                )
                password = ""
                confirmation = ""
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private func label(_ title: String, systemImage: String) -> some View {
        if isWorking {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        } else {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
    }
}
