import SwiftUI

struct EntryDetailView: View {
    @Environment(SessionController.self) private var session
    @Environment(VaultService.self) private var vault
    @Environment(\.dismiss) private var dismiss

    @Bindable var entry: PasswordEntry

    @State private var revealedPassword: String?
    @State private var showingEditor = false
    @State private var pendingDelete = false
    @State private var didCopyPassword = false
    @State private var banner: String?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Button(action: toggleReveal) {
                    Text(revealedPassword ?? "••••••••")
                        .font(.title2.monospaced())
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(revealedPassword == nil ? "显示密码" : "隐藏密码")

                Button(didCopyPassword ? "已复制" : "复制密码") {
                    copyPassword()
                }
                .nativeProminentButton()
                .listRowBackground(Color.clear)
            }

            Section {
                if !entry.username.isEmpty {
                    Button {
                        ClipboardService.copyText(entry.username)
                        showBanner("已复制账号")
                    } label: {
                        LabeledContent("账号", value: entry.username)
                    }
                    .foregroundStyle(.primary)
                }
                if let url = entry.url, !url.isEmpty {
                    Button {
                        ClipboardService.copyText(url)
                        showBanner("已复制网址")
                    } label: {
                        LabeledContent("网址", value: url)
                    }
                    .foregroundStyle(.primary)
                }
            }

            if let notes = entry.notes, !notes.isEmpty {
                Section("备注") {
                    Text(notes)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(entry.title.isEmpty ? "密码" : entry.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    try? vault.toggleFavorite(entry)
                } label: {
                    Image(systemName: entry.isFavorite ? "star.fill" : "star")
                }
                .accessibilityLabel(entry.isFavorite ? "取消收藏" : "收藏")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("编辑") { showingEditor = true }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button("删除", role: .destructive) {
                pendingDelete = true
            }
            .padding(.bottom, 8)
        }
        .overlay(alignment: .top) {
            if let banner {
                CopyBanner(text: banner)
                    .padding(.top, 8)
            }
        }
        .sheet(isPresented: $showingEditor) {
            EntryEditorView(mode: .edit(entry))
        }
        .confirmationDialog("删除这个密码？", isPresented: $pendingDelete, titleVisibility: .visible) {
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
            _ = try vault.copyPassword(entry)
            didCopyPassword = true
            showBanner(ClipboardService.copiedSecretMessage)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func showBanner(_ text: String) {
        banner = text
        Task {
            try? await Task.sleep(for: .seconds(2))
            if banner == text {
                banner = nil
            }
        }
    }

    private func clearSensitiveState() {
        revealedPassword = nil
        didCopyPassword = false
    }
}
