import SwiftUI

struct MigrationView: View {
    @Environment(SessionController.self) private var session

    @State private var password = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("以前的主密码", text: $password)
                        .textContentType(.none)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit { migrate() }
                } footer: {
                    Text("验证一次后，会改成 App 密码，并可同时开启面容 ID。")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("更新解锁方式")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("继续", action: migrate)
                            .disabled(password.isEmpty)
                    }
                }
            }
            .disabled(isWorking)
        }
    }

    private func migrate() {
        guard !password.isEmpty else { return }
        errorMessage = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await session.migrateFromMasterPassword(password)
                password = ""
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
