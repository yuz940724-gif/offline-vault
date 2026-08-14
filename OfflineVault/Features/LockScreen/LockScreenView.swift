import SwiftUI

struct LockScreenView: View {
    @Environment(SessionController.self) private var session

    @State private var password = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var didAutoPrompt = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(.tint)
                    Text("Offline Vault")
                        .font(.largeTitle.weight(.bold))
                    Text("数据永不离开这台设备")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VaultCard {
                    VStack(spacing: 16) {
                        SecureField("主密码", text: $password)
                            .textContentType(.none)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.go)
                            .onSubmit { unlockWithPassword() }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: unlockWithPassword) {
                            actionLabel("解锁", systemImage: "key.fill")
                        }
                        .vaultProminentButton()
                        .disabled(password.isEmpty || isWorking)

                        if session.isBiometricsEnabled && session.biometricKind != .none {
                            Button(action: unlockWithBiometrics) {
                                Label(
                                    "使用\(session.biometricKind.title)",
                                    systemImage: session.biometricKind.systemImage
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .vaultGlassButton()
                            .disabled(isWorking)
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
                Text("后台会立即锁定。解锁后的密钥只保留在内存中。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
            }
            .background(VaultBackdrop())
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            session.bootstrap()
            autoPromptBiometricsIfNeeded()
        }
    }

    private func autoPromptBiometricsIfNeeded() {
        guard !didAutoPrompt, session.isBiometricsEnabled, session.biometricKind != .none else { return }
        didAutoPrompt = true
        unlockWithBiometrics()
    }

    private func unlockWithPassword() {
        guard !password.isEmpty else { return }
        errorMessage = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await session.unlockWithMasterPassword(password)
                password = ""
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func unlockWithBiometrics() {
        errorMessage = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await session.unlockWithBiometrics()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private func actionLabel(_ title: String, systemImage: String) -> some View {
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

struct VaultBackdrop: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.18),
                    Color.clear,
                    Color.accentColor.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}
