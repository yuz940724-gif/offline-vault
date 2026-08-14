import SwiftData
import SwiftUI

struct VaultListView: View {
    @Environment(SessionController.self) private var session
    @Environment(VaultService.self) private var vault
    @Query(sort: \PasswordEntry.updatedAt, order: .reverse) private var entries: [PasswordEntry]

    @State private var searchText = ""
    @State private var showingEditor = false
    @State private var showingSettings = false
    @State private var pendingDelete: PasswordEntry?

    private var filtered: [PasswordEntry] {
        entries
            .filter { $0.matches(query: searchText) }
            .sorted { lhs, rhs in
                if lhs.isFavorite != rhs.isFavorite {
                    return lhs.isFavorite && !rhs.isFavorite
                }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    EmptyStateView(
                        systemImage: "key.horizontal",
                        title: "还没有条目",
                        message: "添加第一个密码。明文只会在解锁后的内存中出现。"
                    )
                } else if filtered.isEmpty {
                    EmptyStateView(
                        systemImage: "magnifyingglass",
                        title: "没有匹配结果",
                        message: "试试标题、用户名或备注中的其他关键词。"
                    )
                } else {
                    List {
                        ForEach(filtered, id: \.id) { entry in
                            NavigationLink(value: entry.id) {
                                EntryRowView(entry: entry)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDelete = entry
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                                Button {
                                    try? vault.toggleFavorite(entry)
                                } label: {
                                    Label(
                                        entry.isFavorite ? "取消收藏" : "收藏",
                                        systemImage: entry.isFavorite ? "star.slash" : "star"
                                    )
                                }
                                .tint(.orange)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("保险库")
            .navigationDestination(for: UUID.self) { id in
                if let entry = entries.first(where: { $0.id == id }) {
                    EntryDetailView(entry: entry)
                }
            }
            .searchable(text: $searchText, prompt: "搜索标题、用户名、备注")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("设置")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        session.lock()
                    } label: {
                        Image(systemName: "lock.fill")
                    }
                    .accessibilityLabel("立即锁定")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("添加条目")
                }
            }
            .sheet(isPresented: $showingEditor) {
                EntryEditorView(mode: .create)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .confirmationDialog(
                "删除这个条目？",
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
            } message: {
                Text("删除后无法恢复。")
            }
        }
    }
}

struct EntryRowView: View {
    let entry: PasswordEntry

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text(entry.title.prefix(1).uppercased())
                    .font(.headline)
                    .foregroundStyle(.tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.title.isEmpty ? "未命名" : entry.title)
                        .font(.headline)
                    if entry.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Text(entry.username.isEmpty ? "无用户名" : entry.username)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
