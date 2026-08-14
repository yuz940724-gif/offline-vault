import SwiftUI

struct SetupVaultView: View {
    @Environment(SessionController.self) private var session

    @State private var password = ""
    @State private var confirmation = ""
    @State private var enableFaceID = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("App 密码", text: $password)
                        .textContentType(.none)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("再次输入", text: $confirmation)
                        .textContentType(.none)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    StrengthMeter(password: password)
                } footer: {
                    Text("打开 App 时使用。密码只在这台 iPhone 上验证，不会联网。")
                }

                if session.canUseFaceID {
                    Section {
                        Toggle(session.biometricKind.title, isOn: $enableFaceID)
                    } footer: {
                        Text("开启后，打开 App 会先尝试\(session.biometricKind.title)。失败时再用 App 密码。")
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("开始", action: start)
                            .disabled(!canStart)
                    }
                }
            }
            .disabled(isWorking)
            .onAppear {
                enableFaceID = session.canUseFaceID
            }
        }
    }

    private var canStart: Bool {
        password == confirmation
            && PasswordStrengthEvaluator.evaluate(password).isAcceptableForMasterPassword
    }

    private func start() {
        errorMessage = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await session.completeFirstRun(
                    appPassword: password,
                    confirmation: confirmation,
                    enableFaceID: enableFaceID
                )
                password = ""
                confirmation = ""
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
