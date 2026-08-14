import SwiftUI

struct LockScreenView: View {
    @Environment(SessionController.self) private var session

    @State private var password = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showPassword = false
    @State private var didAutoPrompt = false

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
        }
    }

    private func autoPromptIfNeeded() {
        guard !didAutoPrompt, session.isFaceIDEnabled else { return }
        didAutoPrompt = true
        unlockWithFaceID()
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
}
