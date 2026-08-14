import SwiftUI

struct EntryEditorView: View {
    enum Mode {
        case create
        case edit(PasswordEntry)
    }

    @Environment(VaultService.self) private var vault
    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    var prefilledTitle: String = ""

    @State private var title = ""
    @State private var username = ""
    @State private var password = ""
    @State private var url = ""
    @State private var notes = ""
    @State private var isFavorite = false
    @State private var showingMore = false
    @State private var showingComplexGenerator = false
    @State private var confirmEmptyPassword = false
    @State private var errorMessage: String?
    @State private var didLoad = false
    @State private var didSaveAndKeep = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名称", text: $title)
                    TextField("账号", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    SecureField("密码", text: $password)
                        .textContentType(.none)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("换一条") {
                        refreshSimplePassword()
                    }
                    Button("复杂生成") {
                        showingComplexGenerator = true
                    }
                }

                Section {
                    DisclosureGroup("更多", isExpanded: $showingMore) {
                        TextField("网址", text: $url)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("备注", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                        Toggle("收藏", isOn: $isFavorite)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成", action: attemptSave)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showingComplexGenerator) {
                PasswordGeneratorView(initialPassword: password) { generated in
                    password = generated
                }
            }
            .confirmationDialog("没有密码，确定保存吗？", isPresented: $confirmEmptyPassword, titleVisibility: .visible) {
                Button("保存") { save() }
                Button("取消", role: .cancel) {}
            }
            .onAppear(perform: loadIfNeeded)
            .onDisappear {
                if !didSaveAndKeep {
                    password = ""
                }
            }
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .create: return "记下一条"
        case .edit: return "编辑"
        }
    }

    private func refreshSimplePassword() {
        var options = PasswordGeneratorOptions()
        options.length = 16
        if let next = try? PasswordGenerator.generate(options) {
            password = next
        }
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        if case .edit(let entry) = mode {
            title = entry.title
            username = entry.username
            url = entry.url ?? ""
            notes = entry.notes ?? ""
            isFavorite = entry.isFavorite
            showingMore = entry.url != nil || entry.notes != nil || entry.isFavorite
            do {
                password = try vault.decryptPassword(entry)
            } catch {
                errorMessage = error.localizedDescription
            }
        } else if !prefilledTitle.isEmpty {
            title = prefilledTitle
        }
    }

    private func attemptSave() {
        if password.isEmpty {
            confirmEmptyPassword = true
        } else {
            save()
        }
    }

    private func save() {
        errorMessage = nil
        do {
            switch mode {
            case .create:
                try vault.create(
                    title: title,
                    username: username,
                    password: password,
                    url: url,
                    notes: notes,
                    category: nil,
                    isFavorite: isFavorite
                )
            case .edit(let entry):
                try vault.update(
                    entry,
                    title: title,
                    username: username,
                    password: password,
                    url: url,
                    notes: notes,
                    category: entry.category,
                    isFavorite: isFavorite
                )
            }
            didSaveAndKeep = true
            password = ""
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
