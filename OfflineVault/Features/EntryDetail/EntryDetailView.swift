import SwiftUI

struct EntryDetailView: View {
    @Environment(SessionController.self) private var session
    @Environment(VaultService.self) private var vault
    @Environment(\.dismiss) private var dismiss

    @Bindable var entry: PasswordEntry

    @State private var revealedPassword: String?
    @State private var showingEditor = false
    @State private var pendingDelete = false
    @State private var copiedMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("账户") {
                labeled("名称", entry.title)
                copyRow(title: "用户名", value: entry.username, secret: false)
                passwordRow
                if let url = entry.url, !url.isEmpty {
                    labeled("网址", url)
                }
                if let category = entry.category, !category.isEmpty {
                    labeled("分类", category)
                }
            }

            if let notes = entry.notes, !notes.isEmpty {
                Section("备注") {
                    Text(notes)
                        .font(.body)
                }
            }

            Section("时间") {
                labeled("创建", entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                labeled("更新", entry.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }

            if let copiedMessage {
                Section {
                    Text(copiedMessage)
                        .font(.footnote)
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
        .navigationTitle(entry.title.isEmpty ? "条目" : entry.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    try? vault.toggleFavorite(entry)
                } label: {
                    Image(systemName: entry.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(entry.isFavorite ? .orange : .primary)
                }
                .accessibilityLabel(entry.isFavorite ? "取消收藏" : "收藏")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("编辑") { showingEditor = true }
            }
            ToolbarItem(placement: .bottomBar) {
                Button("删除", role: .destructive) { pendingDelete = true }
            }
        }
        .sheet(isPresented: $showingEditor) {
            EntryEditorView(mode: .edit(entry))
        }
        .confirmationDialog("删除这个条目？", isPresented: $pendingDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                try? vault.delete(entry)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
        .onDisappear { clearSensitiveState() }
        .onReceive(NotificationCenter.default.publisher(for: .vaultDidLock)) { _ in
            clearSensitiveState()
        }
        .onChange(of: session.phase) { _, phase in
            if phase != .unlocked {
                clearSensitiveState()
            }
        }
    }

    private var passwordRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("密码")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Text(revealedPassword ?? "••••••••")
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                Spacer()
                Button {
                    toggleReveal()
                } label: {
                    Image(systemName: revealedPassword == nil ? "eye" : "eye.slash")
                }
                .accessibilityLabel(revealedPassword == nil ? "显示密码" : "隐藏密码")
                Button {
                    copyPassword()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .accessibilityLabel("复制密码")
            }
        }
        .padding(.vertical, 4)
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
        }
    }

    private func copyRow(title: String, value: String, secret: Bool) -> some View {
        HStack {
            labeled(title, value.isEmpty ? "—" : value)
            Spacer()
            if !value.isEmpty {
                Button {
                    if secret {
                        ClipboardService.copySecret(value)
                        copiedMessage = "已复制，将在 30 秒后从剪贴板清除"
                    } else {
                        ClipboardService.copyText(value)
                        copiedMessage = "已复制\(title)"
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .accessibilityLabel("复制\(title)")
            }
        }
    }

    private func toggleReveal() {
        errorMessage = nil
        if revealedPassword != nil {
            revealedPassword = nil
            return
        }
        do {
            revealedPassword = try vault.decryptPassword(entry)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func copyPassword() {
        errorMessage = nil
        do {
            let password = try vault.decryptPassword(entry)
            ClipboardService.copySecret(password)
            copiedMessage = "密码已复制，将在 30 秒后从剪贴板清除"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearSensitiveState() {
        revealedPassword = nil
    }
}
