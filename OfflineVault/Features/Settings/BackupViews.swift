import SwiftUI
import UniformTypeIdentifiers

struct VaultBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.vaultBackup, .data] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw BackupError.invalidFile
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct BackupExportView: View {
    @Environment(VaultService.self) private var vault
    @Environment(\.dismiss) private var dismiss

    var onFinished: (String) -> Void

    @State private var password = ""
    @State private var confirmation = ""
    @State private var document: VaultBackupDocument?
    @State private var showingExporter = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("备份密码", text: $password)
                        .textContentType(.none)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("再次输入", text: $confirmation)
                        .textContentType(.none)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    StrengthMeter(password: password)
                } footer: {
                    Text("请使用独立的备份密码。导出的 .vault 文件只保存在你选择的位置。")
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("导出备份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("导出", action: prepareExport)
                            .disabled(!canExport)
                    }
                }
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: document,
                contentType: .vaultBackup,
                defaultFilename: defaultFilename
            ) { result in
                switch result {
                case .success:
                    onFinished("备份已导出")
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private var canExport: Bool {
        password == confirmation && PasswordStrengthEvaluator.evaluate(password).isAcceptableForMasterPassword
    }

    private var defaultFilename: String {
        let stamp = Date().formatted(.dateTime.year().month().day())
        return "offline-vault-\(stamp).vault"
    }

    private func prepareExport() {
        errorMessage = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let entries = try vault.allEntries()
                let data = try BackupService.export(
                    entries: entries,
                    decryptPassword: { try vault.decryptPassword($0) },
                    password: password
                )
                document = VaultBackupDocument(data: data)
                showingExporter = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct BackupImportView: View {
    @Environment(VaultService.self) private var vault
    @Environment(\.dismiss) private var dismiss

    var onFinished: (String) -> Void

    @State private var password = ""
    @State private var showingImporter = false
    @State private var pickedData: Data?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button(pickedData == nil ? "选择备份" : "已选择备份") {
                        showingImporter = true
                    }
                    SecureField("备份密码", text: $password)
                        .textContentType(.none)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("按条目 ID 合并。已存在的条目会被覆盖。")
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("导入备份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("导入", action: importBackup)
                            .disabled(pickedData == nil || password.isEmpty)
                    }
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.vaultBackup, .data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    loadFile(url)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func loadFile(_ url: URL) {
        errorMessage = nil
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            pickedData = try Data(contentsOf: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importBackup() {
        guard let pickedData else { return }
        errorMessage = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let payload = try BackupService.importData(pickedData, password: password)
                try vault.importEntries(payload.entries)
                onFinished("已导入 \(payload.entries.count) 个条目")
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
