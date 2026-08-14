import SwiftData
import SwiftUI

struct VaultListView: View {
    @Environment(VaultService.self) private var vault
    @Query private var entries: [PasswordEntry]

    @State private var searchText = ""
    @State private var showingEditor = false
    @State private var showingGenerator = false
    @State private var editorPrefillTitle = ""
    @State private var editingEntry: PasswordEntry?
    @State private var pendingDelete: PasswordEntry?
    @State private var banner: String?

    private var filtered: [PasswordEntry] {
        entries
            .filter { $0.matches(query: searchText) }
            .sorted { lhs, rhs in
                if lhs.isFavorite != rhs.isFavorite {
                    return lhs.isFavorite && !rhs.isFavorite
                }
                let left = lhs.lastUsedAt ?? lhs.updatedAt
                let right = rhs.lastUsedAt ?? rhs.updatedAt
                return left > right
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty && searchText.isEmpty {
                    ContentUnavailableView {
                        Label("还没有密码", systemImage: "key")
                    } actions: {
                        Button("记下一条") {
                            editorPrefillTitle = ""
                            showingEditor = true
                        }
                        .nativeProminentButton()
                    }
                } else if filtered.isEmpty {
                    ContentUnavailableView {
                        Label("没有结果", systemImage: "magnifyingglass")
                    } description: {
                        Text(searchText)
                    } actions: {
                        Button("记下「\(searchText)」") {
                            editorPrefillTitle = searchText
                            showingEditor = true
                        }
                        .nativeProminentButton()
                    }
                } else {
                    List {
                        ForEach(filtered, id: \.id) { entry in
                            NavigationLink(value: entry.id) {
                                EntryRowView(entry: entry)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    copyPassword(entry)
                                } label: {
                                    Label("复制", systemImage: "doc.on.doc")
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDelete = entry
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button("复制密码", systemImage: "key") {
                                    copyPassword(entry)
                                }
                                if !entry.username.isEmpty {
                                    Button("复制账号", systemImage: "person") {
                                        ClipboardService.copyText(entry.username)
                                        showBanner("已复制账号")
                                    }
                                }
                                Button("编辑", systemImage: "pencil") {
                                    editingEntry = entry
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("所有密码")
            .navigationDestination(for: UUID.self) { id in
                if let entry = entries.first(where: { $0.id == id }) {
                    EntryDetailView(entry: entry)
                }
            }
            .searchable(text: $searchText, prompt: "搜索")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingGenerator = true
                    } label: {
                        Image(systemName: "wand.and.stars")
                    }
                    .accessibilityLabel("复杂密码生成器")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorPrefillTitle = ""
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("记下一条")
                }
            }
            .sheet(isPresented: $showingEditor) {
                EntryEditorView(mode: .create, prefilledTitle: editorPrefillTitle)
            }
            .sheet(item: $editingEntry) { entry in
                EntryEditorView(mode: .edit(entry))
            }
            .sheet(isPresented: $showingGenerator) {
                PasswordGeneratorView()
            }
            .overlay(alignment: .top) {
                if let banner {
                    CopyBanner(text: banner)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: banner)
            .confirmationDialog(
                "删除这个密码？",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("删除", role: .destructive) {
                    if let pendingDelete {
                        try? vault.delete(pendingDelete)
                    }
                    pendingDelete = nil
                }
                Button("取消", role: .cancel) {
                    pendingDelete = nil
                }
            }
        }
    }

    private func copyPassword(_ entry: PasswordEntry) {
        do {
            _ = try vault.copyPassword(entry)
            showBanner(ClipboardService.copiedSecretMessage)
        } catch {
            showBanner(error.localizedDescription)
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
}

struct EntryRowView: View {
    let entry: PasswordEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(entry.title.isEmpty ? "未命名" : entry.title)
                if entry.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if !entry.username.isEmpty {
                Text(entry.username)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
