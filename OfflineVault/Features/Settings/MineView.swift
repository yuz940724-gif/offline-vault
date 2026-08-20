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
    @AppStorage(AppAppearance.storageKey) private var appearanceRawValue = AppAppearance.system.rawValue

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    protectionSummary

                    SettingsCard(
                        title: "安全与解锁",
                        footer: lockFooter
                    ) {
                        HStack(spacing: 14) {
                            SettingsLeadingLabel(
                                title: "App 密码",
                                systemImage: "lock.fill",
                                tint: .indigo
                            )
                            Spacer(minLength: 12)
                            Toggle("App 密码", isOn: appPasswordBinding)
                                .labelsHidden()
                                .disabled(isWorking)
                        }
                        .padding(14)

                        if session.canUseFaceID {
                            SettingsDivider()

                            HStack(spacing: 14) {
                                SettingsLeadingLabel(
                                    title: session.biometricKind.title,
                                    systemImage: "faceid",
                                    tint: .green
                                )
                                Spacer(minLength: 12)
                                Toggle(session.biometricKind.title, isOn: faceIDBinding)
                                    .labelsHidden()
                                    .disabled(isWorking)
                            }
                            .padding(14)
                        }
                    }

                    SettingsCard(
                        title: "偏好设置",
                        footer: "自动锁定会在无操作超时或重新进入 App 时生效。"
                    ) {
                        Button {
                            showingAutoLockPicker = true
                            session.registerActivity()
                        } label: {
                            SettingsNavigationRow(
                                title: "自动锁定",
                                systemImage: "timer",
                                tint: .orange,
                                value: AutoLockController.timeoutTitle(timeout)
                            )
                        }
                        .buttonStyle(SettingsPressButtonStyle())
                        .accessibilityLabel("自动锁定时间，当前为\(AutoLockController.timeoutTitle(timeout))")

                        SettingsDivider()

                        NavigationLink {
                            AppearanceSelectionView(selection: $appearanceRawValue)
                        } label: {
                            SettingsNavigationRow(
                                title: "外观",
                                systemImage: "circle.lefthalf.filled",
                                tint: .purple,
                                value: selectedAppearanceTitle
                            )
                        }
                        .buttonStyle(SettingsPressButtonStyle())

                        SettingsDivider()

                        NavigationLink {
                            GroupSettingsView()
                        } label: {
                            SettingsNavigationRow(
                                title: "分组设置",
                                systemImage: "folder.fill",
                                tint: .blue
                            )
                        }
                        .buttonStyle(SettingsPressButtonStyle())
                    }

                    SettingsCard(
                        title: "备份与迁移",
                        footer: "导出加密的 .vault 文件，再通过隔空投送或“文件”导入新 iPhone。"
                    ) {
                        Button {
                            activeSheet = .export
                            session.registerActivity()
                        } label: {
                            SettingsNavigationRow(
                                title: "导出备份",
                                systemImage: "square.and.arrow.up.fill",
                                tint: .blue,
                                showsChevron: false
                            )
                        }
                        .buttonStyle(SettingsPressButtonStyle())

                        SettingsDivider()

                        Button {
                            activeSheet = .import
                            session.registerActivity()
                        } label: {
                            SettingsNavigationRow(
                                title: "导入备份",
                                systemImage: "square.and.arrow.down.fill",
                                tint: .teal,
                                showsChevron: false
                            )
                        }
                        .buttonStyle(SettingsPressButtonStyle())
                    }

                    SettingsCard(title: "隐私") {
                        SettingsNavigationRow(
                            title: "网络连接",
                            systemImage: "wifi.slash",
                            tint: .green,
                            value: "不连接",
                            showsChevron: false
                        )
                    }

                    Button(role: .destructive) {
                        showingReset = true
                    } label: {
                        Label("删除本机全部密码", systemImage: "trash.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(SettingsPressButtonStyle())

                    if let statusMessage {
                        SettingsMessage(text: statusMessage, tint: .green, systemImage: "checkmark.circle.fill")
                    }

                    if let errorMessage {
                        SettingsMessage(text: errorMessage, tint: .red, systemImage: "exclamationmark.triangle.fill")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 120)
            }
            .background(Color(uiColor: .systemGroupedBackground))
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

    private var selectedAppearanceTitle: String {
        AppAppearance(rawValue: appearanceRawValue)?.title ?? AppAppearance.system.title
    }

    private var isProtected: Bool {
        session.isAppPasswordEnabled || session.isFaceIDEnabled
    }

    private var protectionSummary: some View {
        HStack(spacing: 16) {
            Image(systemName: isProtected ? "lock.shield.fill" : "exclamationmark.shield.fill")
                .font(.system(size: 27, weight: .semibold))
                .foregroundStyle(isProtected ? Color.green : Color.orange)
                .frame(width: 56, height: 56)
                .background(
                    (isProtected ? Color.green : Color.orange).opacity(0.13),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(isProtected ? "本机保护已开启" : "本机保护未开启")
                    .font(.headline)
                Text("密码不会上传，只保存在这台 iPhone。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)
        }
        .padding(18)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(alignment: .topTrailing) {
            Text("仅本机")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.green)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.green.opacity(0.12), in: Capsule())
                .padding(12)
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

private struct SettingsCard<Content: View>: View {
    let title: String
    let footer: String?
    private let content: Content

    init(
        title: String,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content
            }
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            }

            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsLeadingLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }
}

private struct SettingsNavigationRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    var value: String? = nil
    var showsChevron = true

    var body: some View {
        HStack(spacing: 14) {
            SettingsLeadingLabel(title: title, systemImage: systemImage, tint: tint)

            Spacer(minLength: 12)

            if let value {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 62)
    }
}

private struct SettingsMessage: View {
    let text: String
    let tint: Color
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SettingsPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}

private struct AppearanceSelectionView: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(AppAppearance.allCases) { appearance in
                    Button {
                        selection = appearance.rawValue
                        dismiss()
                    } label: {
                        HStack {
                            Label(appearance.title, systemImage: appearance.systemImage)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selection == appearance.rawValue {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                }
            } footer: {
                Text("跟随系统会随 iPhone 的外观设置自动切换。")
            }
        }
        .navigationTitle("外观")
        .navigationBarTitleDisplayMode(.inline)
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
