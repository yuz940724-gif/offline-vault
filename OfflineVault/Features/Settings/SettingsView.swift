import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(SessionController.self) private var session
    @Environment(VaultService.self) private var vault
    @Environment(\.dismiss) private var dismiss

    @State private var timeout: TimeInterval = AutoLockController.defaultTimeout
    @State private var showingChangePassword = false
    @State private var showingExport = false
    @State private var showingImport = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var isTogglingBiometrics = false

    var body: some View {
        NavigationStack {
            Form {
                Section("安全") {
                    Picker("无操作自动锁定", selection: $timeout) {
                        ForEach(AutoLockController.timeoutOptions, id: \.self) { value in
                            Text(AutoLockController.timeoutTitle(value)).tag(value)
                        }
                    }
                    .onChange(of: timeout) { _, newValue in
                        session.autoLock.timeout = newValue
                        session.registerActivity()
                    }

                    if session.biometricKind != .none {
                        Toggle(
                            "使用\(session.biometricKind.title)解锁",
                            isOn: Binding(
                                get: { session.isBiometricsEnabled },
                                set: { enabled in
                                    toggleBiometrics(enabled)
                                }
                            )
                        )
                        .disabled(isTogglingBiometrics)
                    }

                    Button("修改主密码") {
                        showingChangePassword = true
                    }
                }

                Section("备份") {
                    Button("导出加密备份") {
                        showingExport = true
                    }
                    Button("导入加密备份") {
                        showingImport = true
                    }
                    Text("备份文件使用独立密码加密。导出和导入都只在本机完成。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("关于") {
                    LabeledContent("应用", value: "Offline Vault")
                    LabeledContent("模式", value: "完全离线")
                    Text("不包含账号、云同步、分析或任何网络请求。数据使用 AES-256-GCM 加密，主密码仅用于派生密钥。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showingChangePassword) {
                ChangeMasterPasswordView()
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
            .onAppear {
                timeout = session.autoLock.timeout
            }
        }
    }

    private func toggleBiometrics(_ enabled: Bool) {
        errorMessage = nil
        isTogglingBiometrics = true
        defer { isTogglingBiometrics = false }
        do {
            if enabled {
                try session.enableBiometricsAfterUnlock()
                statusMessage = "已开启\(session.biometricKind.title)"
            } else {
                try session.disableBiometrics()
                statusMessage = "已关闭生物识别解锁"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
