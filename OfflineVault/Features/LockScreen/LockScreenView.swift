import SwiftUI

struct LockScreenView: View {
    @Environment(SessionController.self) private var session
    @Environment(\.scenePhase) private var scenePhase
#if targetEnvironment(simulator)
    @Environment(VaultService.self) private var vault
#endif

    @State private var password = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showPassword = false
    @State private var didAutoPrompt = false
#if targetEnvironment(simulator)
    @State private var showingSimulatorReset = false
#endif

    var body: some View {
        NavigationStack {
            Form {
                if session.isFaceIDEnabled {
                    Section {
                        Button {
                            unlockWithFaceID()
                        } label: {
                            Label(session.biometricKind.unlockTitle, systemImage: session.biometricKind.systemImage)
                        }
                        .disabled(isWorking)
                    }
                }

                if session.isAppPasswordEnabled && (showPassword || !session.isFaceIDEnabled) {
                    Section {
                        SecureField("App 密码", text: $password)
                            .textContentType(.none)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.go)
                            .onSubmit { unlockWithPassword() }
                        Button("打开", action: unlockWithPassword)
                            .disabled(password.isEmpty || isWorking)
                    }
                }

                if session.isFaceIDEnabled && session.isAppPasswordEnabled && !showPassword {
                    Section {
                        Button("使用 App 密码") {
                            showPassword = true
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

#if targetEnvironment(simulator)
                Section("模拟器开发模式") {
                    Button("忘记密码，直接进入模拟器") {
                        showingSimulatorReset = true
                    }
                    Text("仅模拟器有效。首次使用会清空模拟器中的本地密码数据，真机不会显示此选项。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
#endif

                if session.isFaceIDEnabled && errorMessage != nil {
                    Section {
                        Button("再次尝试\(session.biometricKind.title)", action: unlockWithFaceID)
                            .disabled(isWorking)
                    }
                }
            }
            .navigationTitle("密码")
            .overlay {
                if isWorking {
                    ProgressView()
                }
            }
            .onAppear {
                session.bootstrap()
                if session.isAppPasswordEnabled && !session.isFaceIDEnabled {
                    showPassword = true
                }
                autoPromptIfNeeded()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    autoPromptIfNeeded()
                } else {
                    didAutoPrompt = false
                }
            }
#if targetEnvironment(simulator)
            .confirmationDialog(
                "清空模拟器中的密码数据？",
                isPresented: $showingSimulatorReset,
                titleVisibility: .visible
            ) {
                Button("清空并直接进入", role: .destructive) {
                    resetForSimulatorBypass()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("忘记的密码无法解密旧数据。此操作只影响模拟器，不影响真机。")
            }
#endif
        }
    }

    private func autoPromptIfNeeded() {
        guard scenePhase == .active, !didAutoPrompt, session.isFaceIDEnabled else { return }
        didAutoPrompt = true
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, scenePhase == .active else { return }
            unlockWithFaceID()
        }
    }

    private func unlockWithFaceID() {
        errorMessage = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await session.unlockWithFaceID()
            } catch {
                errorMessage = error.localizedDescription
                if session.isAppPasswordEnabled {
                    showPassword = true
                }
            }
        }
    }

    private func unlockWithPassword() {
        guard !password.isEmpty else { return }
        errorMessage = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await session.unlockWithAppPassword(password)
                password = ""
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

#if targetEnvironment(simulator)
    private func resetForSimulatorBypass() {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try vault.resetForSimulatorBypass()
            password = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
#endif
}
