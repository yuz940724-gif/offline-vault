import SwiftUI

struct ChangeMasterPasswordView: View {
    @Environment(VaultService.self) private var vault
    @Environment(\.dismiss) private var dismiss

    @State private var current = ""
    @State private var newPassword = ""
    @State private var confirmation = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("当前主密码") {
                    SecureField("当前主密码", text: $current)
                        .textContentType(.none)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("新主密码") {
                    SecureField("新主密码", text: $newPassword)
                        .textContentType(.none)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("再次输入", text: $confirmation)
                        .textContentType(.none)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    StrengthMeter(password: newPassword)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("修改主密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("更新", action: change)
                            .disabled(!canChange)
                    }
                }
            }
        }
    }

    private var canChange: Bool {
        !current.isEmpty
            && newPassword == confirmation
            && PasswordStrengthEvaluator.evaluate(newPassword).isAcceptableForMasterPassword
    }

    private func change() {
        errorMessage = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await vault.changeMasterPassword(
                    current: current,
                    new: newPassword,
                    confirmation: confirmation
                )
                current = ""
                newPassword = ""
                confirmation = ""
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
