import SwiftUI
import UniformTypeIdentifiers

struct VaultBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.vaultBackup, .data] }
    static var writableContentTypes: [UTType] { [.vaultBackup] }

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
                    SecureField("确认备份密码", text: $confirmation)
                        .textContentType(.none)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    StrengthMeter(password: password)
                } footer: {
                    Text("请填写两次相同的独立备份密码。建议至少 12 位；密码越弱，备份文件越容易被猜解。导入时必须使用同一个密码。")
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
                            .disabled(isWorking)
                    }
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
        .onChange(of: password) { _, _ in
            errorMessage = nil
        }
        .onChange(of: confirmation) { _, _ in
            errorMessage = nil
        }
    }

    private var defaultFilename: String {
        let stamp = Date().formatted(.dateTime.year().month().day())
        return "offline-vault-\(stamp).vault"
    }

    private func prepareExport() {
        errorMessage = nil
        guard !password.isEmpty else {
            errorMessage = "请先设置备份密码"
            return
        }
        guard password == confirmation else {
            errorMessage = "两次输入的备份密码不一致"
            return
        }
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
    @State private var pickedFilename: String?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button(pickedFilename == nil ? "选择备份" : "重新选择备份") {
                        errorMessage = nil
                        showingImporter = true
                    }
                    .contentShape(Rectangle())
                    if let pickedFilename {
                        LabeledContent("文件", value: pickedFilename)
                    }
                    SecureField("备份密码", text: $password)
                        .textContentType(.none)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("按条目 ID 合并。已存在的条目会被覆盖。")
                }
                if pickedData != nil {
                    Section {
                        Label("备份文件已读入", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } footer: {
                        Text("输入导出时设置的备份密码，然后点击右上角“导入”。")
                    }
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
                            .disabled(isWorking)
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
            pickedFilename = url.lastPathComponent
        } catch {
            pickedData = nil
            pickedFilename = nil
            errorMessage = error.localizedDescription
        }
    }

    private func importBackup() {
        errorMessage = nil
        guard pickedData != nil else {
            errorMessage = "请先选择 .vault 备份文件"
            return
        }
        guard !password.isEmpty else {
            errorMessage = "请输入备份密码"
            return
        }
        guard let pickedData else { return }
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
