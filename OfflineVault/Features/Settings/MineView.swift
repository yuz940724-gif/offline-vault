import SwiftUI

struct MineView: View {
    @Environment(SessionController.self) private var session
    @Environment(VaultService.self) private var vault

    @State private var timeout: TimeInterval = AutoLockController.defaultTimeout
    @State private var showingExport = false
    @State private var showingImport = false
    @State private var showingReset = false
    @State private var showingSetAppPassword = false
    @State private var showingDisableAppPassword = false
    @State private var disablePassword = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: appPasswordBinding) {
                        Text("App 密码")
                    }
                    .disabled(isWorking)

                    if session.canUseFaceID {
                        Toggle(isOn: faceIDBinding) {
                            Text(session.biometricKind.title)
                        }
                        .disabled(isWorking)
                    }
                } footer: {
                    Text(lockFooter)
                }

                Section {
                    Picker("自动锁定", selection: $timeout) {
                        ForEach(AutoLockController.timeoutOptions, id: \.self) { value in
                            Text(AutoLockController.timeoutTitle(value)).tag(value)
                        }
                    }
                    .onChange(of: timeout) { _, newValue in
                        session.autoLock.timeout = newValue
                        session.registerActivity()
                    }
                } footer: {
                    Text("离开 App 会立即锁定。回来时按上面的方式打开。")
                }

                Section {
                    Button("导出备份") { showingExport = true }
                    Button("导入备份") { showingImport = true }
                } footer: {
                    Text("备份文件用单独的密码加密，只保存在你选择的位置。")
                }

                Section {
                    Button("删除本机全部密码", role: .destructive) {
                        showingReset = true
                    }
                } footer: {
                    Text("只删除这台 iPhone 上的数据。无法撤销。")
                }

                Section {
                    LabeledContent("网络", value: "不连接")
                } footer: {
                    Text("密码只存在这台 iPhone 上。")
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("我的")
            .sheet(isPresented: $showingSetAppPassword) {
                SetAppPasswordView { password, confirmation in
                    try await session.enableAppPassword(password, confirmation: confirmation)
                    statusMessage = "已开启 App 密码"
                }
            }
            .sheet(isPresented: $showingDisableAppPassword) {
                disablePasswordSheet
            }
            .sheet(isPresented: $showingExport) {
                BackupExportView { message in
                    statusMessage = message
                }
            }
            .sheet(isPresented: $showingImport) {
                BackupImportView { message in
                    statusMessage = message
                }
            }
            .confirmationDialog("删除本机全部密码？", isPresented: $showingReset, titleVisibility: .visible) {
                Button("删除全部", role: .destructive, action: resetAll)
                Button("取消", role: .cancel) {}
            } message: {
                Text("App 密码和面容 ID 保护也会一起清除。")
            }
            .onAppear {
                timeout = session.autoLock.timeout
            }
        }
    }

    private var lockFooter: String {
        switch (session.isFaceIDEnabled, session.isAppPasswordEnabled) {
        case (true, true):
            return "打开 App 会先使用\(session.biometricKind.title)。失败时再用 App 密码。"
        case (true, false):
            return "打开 App 使用\(session.biometricKind.title)。建议同时开启 App 密码作为后路。"
        case (false, true):
            return "打开 App 使用你设置的 App 密码。"
        case (false, false):
            return "现在打开 App 不再验证。密码没有锁。"
        }
    }

    private var appPasswordBinding: Binding<Bool> {
        Binding(
            get: { session.isAppPasswordEnabled },
            set: { enabled in
                errorMessage = nil
                if enabled {
                    showingSetAppPassword = true
                } else {
                    showingDisableAppPassword = true
                }
            }
        )
    }

    private var faceIDBinding: Binding<Bool> {
        Binding(
            get: { session.isFaceIDEnabled },
            set: { enabled in
                errorMessage = nil
                isWorking = true
                Task {
                    defer { isWorking = false }
                    do {
                        if enabled {
                            try await session.enableFaceID()
                            statusMessage = "已开启\(session.biometricKind.title)"
                        } else {
                            try session.disableFaceID()
                            statusMessage = "已关闭\(session.biometricKind.title)"
                        }
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        )
    }

    private var disablePasswordSheet: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("当前 App 密码", text: $disablePassword)
                        .textContentType(.none)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("关闭前请先确认当前密码。")
                }
            }
            .navigationTitle("关闭 App 密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        disablePassword = ""
                        showingDisableAppPassword = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") {
                        Task { await confirmDisableAppPassword() }
                    }
                    .disabled(disablePassword.isEmpty || isWorking)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func confirmDisableAppPassword() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await session.disableAppPassword(current: disablePassword)
            disablePassword = ""
            showingDisableAppPassword = false
            statusMessage = "已关闭 App 密码"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetAll() {
        errorMessage = nil
        do {
            try vault.resetAllLocalData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SetAppPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    var onSave: (String, String) async throws -> Void

    @State private var password = ""
    @State private var confirmation = ""
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
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("设置 App 密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("开启") {
                            Task { await save() }
                        }
                        .disabled(!canSave)
                    }
                }
            }
        }
    }

    private var canSave: Bool {
        password == confirmation
            && PasswordStrengthEvaluator.evaluate(password).isAcceptableForMasterPassword
    }

    private func save() async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await onSave(password, confirmation)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
