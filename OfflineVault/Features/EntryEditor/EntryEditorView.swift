import SwiftUI

struct EntryEditorView: View {
    enum Mode {
        case create
        case edit(PasswordEntry)
    }

    @Environment(VaultService.self) private var vault
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var title = ""
    @State private var username = ""
    @State private var password = ""
    @State private var url = ""
    @State private var notes = ""
    @State private var category = ""
    @State private var isFavorite = false
    @State private var showingGenerator = false
    @State private var errorMessage: String?
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            Form {
                Section("账户") {
                    TextField("名称", text: $title)
                    TextField("用户名", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("密码", text: $password)
                        .textContentType(.none)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("生成密码") {
                        showingGenerator = true
                    }
                    TextField("网址", text: $url)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("分类（可选）", text: $category)
                    Toggle("收藏", isOn: $isFavorite)
                }

                Section("备注") {
                    TextField("备注", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
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
                    Button("保存", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showingGenerator) {
                PasswordGeneratorView { generated in
                    password = generated
                }
            }
            .onAppear(perform: loadIfNeeded)
            .onDisappear {
                if !didSaveAndKeep {
                    password = ""
                }
            }
        }
    }

    @State private var didSaveAndKeep = false

    private var navigationTitle: String {
        switch mode {
        case .create: return "添加条目"
        case .edit: return "编辑条目"
        }
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        guard case .edit(let entry) = mode else { return }
        title = entry.title
        username = entry.username
        url = entry.url ?? ""
        notes = entry.notes ?? ""
        category = entry.category ?? ""
        isFavorite = entry.isFavorite
        do {
            password = try vault.decryptPassword(entry)
        } catch {
            errorMessage = error.localizedDescription
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
                    category: category,
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
                    category: category,
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
