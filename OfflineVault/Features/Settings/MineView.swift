import SwiftData
import SwiftUI

struct MineView: View {
    @Environment(SessionController.self) private var session
    @Environment(VaultService.self) private var vault

    private enum ActiveSheet: String, Identifiable {
        case setAppPassword
        case disableAppPassword
        case export
        case `import`

        var id: String { rawValue }
    }

    @State private var timeout: TimeInterval = AutoLockController.defaultTimeout
    @State private var showingAutoLockPicker = false
    @State private var activeSheet: ActiveSheet?
    @State private var showingReset = false
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
                    HStack(spacing: 12) {
                        Text("自动锁定")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            showingAutoLockPicker = true
                            session.registerActivity()
                        } label: {
                            HStack(spacing: 4) {
                                Text(AutoLockController.timeoutTitle(timeout))
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("自动锁定时间，当前为\(AutoLockController.timeoutTitle(timeout))")
                    }
                    .contentShape(Rectangle())
                } footer: {
                    Text("在 App 内无操作超过所选时间后锁定。切回 App 时也会检查是否已超时。")
                }

                Section {
                    NavigationLink {
                        GroupSettingsView()
                    } label: {
                        Label("分组设置", systemImage: "folder")
                    }
                } footer: {
                    Text("维护分组。密码编辑时可直接下拉选择。")
                }

                Section {
                    Button("导出备份") {
                        activeSheet = .export
                        session.registerActivity()
                    }
                    .contentShape(Rectangle())
                    Button("导入备份") {
                        activeSheet = .import
                        session.registerActivity()
                    }
                    .contentShape(Rectangle())
                } footer: {
                    Text("换机时：旧机导出 .vault，通过隔空投送或文件发送到新机，再在新机导入。不会自动联网迁移。")
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
        }
        .sheet(isPresented: $showingAutoLockPicker) {
            AutoLockTimePickerView(timeout: $timeout)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .setAppPassword:
                SetAppPasswordView { password, confirmation in
                    try await session.enableAppPassword(password, confirmation: confirmation)
                    statusMessage = "已开启 App 密码"
                }
            case .disableAppPassword:
                disablePasswordSheet
            case .export:
                BackupExportView { message in
                    statusMessage = message
                }
            case .import:
                BackupImportView { message in
                    statusMessage = message
                }
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
        .onChange(of: timeout) { _, value in
            session.autoLock.timeout = value
            session.registerActivity()
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
                    activeSheet = .setAppPassword
                } else {
                    activeSheet = .disableAppPassword
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
                        activeSheet = nil
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
            activeSheet = nil
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

private struct AutoLockTimePickerView: View {
    @Binding var timeout: TimeInterval
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Picker("自动锁定时间", selection: $timeout) {
                ForEach(AutoLockController.timeoutOptions, id: \.self) { value in
                    Text(AutoLockController.timeoutTitle(value)).tag(value)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .navigationTitle("自动锁定时间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(280)])
    }
}

struct GroupSettingsView: View {
    @Environment(VaultService.self) private var vault
    @Query private var groups: [PasswordGroup]
    @Query private var entries: [PasswordEntry]

    @State private var pendingDeleteCategory: String?
    @State private var errorMessage: String?

    private var categories: [String] {
        Set(groups.compactMap { group in
            let value = group.category.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    var body: some View {
        List {
            if groups.isEmpty {
                ContentUnavailableView {
                    Label("还没有分组", systemImage: "folder")
                } description: {
                    Text("点击右上角加号创建分组")
                }
            } else {
                ForEach(categories, id: \.self) { category in
                    HStack {
                        Text(category)
                        Spacer()
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !isUsed(category) {
                            Button(role: .destructive) {
                                pendingDeleteCategory = category
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
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
        .listSectionSpacing(.custom(12))
        .navigationTitle("分组设置")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    GroupEditorView()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("新增分组")
            }
        }
        .confirmationDialog(
            "删除这个空分组？",
            isPresented: Binding(
                get: { pendingDeleteCategory != nil },
                set: { if !$0 { pendingDeleteCategory = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let pendingDeleteCategory {
                    do {
                        try vault.deleteGroup(category: pendingDeleteCategory)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                pendingDeleteCategory = nil
            }
            Button("取消", role: .cancel) {
                pendingDeleteCategory = nil
            }
        } message: {
            Text("已使用的分组不会提供删除操作，避免误改密码归属。")
        }
        .task {
            do {
                try vault.ensureGroupsFromEntries()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func isUsed(_ category: String) -> Bool {
        entries.contains { entry in
            entry.category?.trimmingCharacters(in: .whitespacesAndNewlines) == category
        }
    }
}

struct GroupEditorView: View {
    @Environment(VaultService.self) private var vault
    @Environment(\.dismiss) private var dismiss

    @State private var category = ""
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                TextField("分组名称，例如 ECS", text: $category)
            } footer: {
                Text("密码编辑时可以直接选择这个分组。")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("新增分组")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(!canSave)
            }
        }
        .onChange(of: category) { _, _ in
            errorMessage = nil
        }
    }

    private var canSave: Bool {
        !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        do {
            try vault.createGroup(category: category)
            dismiss()
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
