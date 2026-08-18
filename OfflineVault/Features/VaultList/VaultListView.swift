import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct VaultListView: View {
    private struct GroupSection: Identifiable {
        let key: String?
        let name: String
        let entries: [PasswordEntry]

        var id: String { key ?? "" }
    }

    @Environment(VaultService.self) private var vault
    @Query private var entries: [PasswordEntry]

    @State private var searchText = ""
    @State private var showingEditor = false
    @State private var showingGenerator = false
    @State private var editorPrefillTitle = ""
    @State private var editingEntry: PasswordEntry?
    @State private var pendingDelete: PasswordEntry?
    @State private var banner: String?
    @State private var collapsedGroupKeys: Set<String> = []

    private var filtered: [PasswordEntry] {
        entries.filter { $0.matches(query: searchText) }
    }

    private var groupedEntries: [GroupSection] {
        let parents = Dictionary(grouping: filtered) { entry in
            entry.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        return parents.keys.sorted { lhs, rhs in
            if lhs.isEmpty != rhs.isEmpty {
                return !lhs.isEmpty
            }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }.map { parent in
            return GroupSection(
                key: parent.isEmpty ? nil : parent,
                name: parent.isEmpty ? "未分组" : parent,
                entries: (parents[parent] ?? []).sorted(by: compareForSortOrder)
            )
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
                        ForEach(groupedEntries) { parent in
                            Section {
                                parentGroupView(parent)
                            }
                        }
                    }
                    .listSectionSpacing(.custom(12))
                }
            }
            .navigationTitle("所有密码")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "搜索名称、账号或分组"
            )
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
            .task {
                do {
                    try vault.ensureGroupsFromEntries()
                } catch {
                    showBanner(error.localizedDescription)
                }
            }
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

    private func moveEntry(_ sourceID: UUID, toCategory: String?, beforeID: UUID?) {
        do {
            try vault.moveEntry(entryID: sourceID, toCategory: toCategory, before: beforeID)
        } catch {
            showBanner(error.localizedDescription)
        }
    }

    @ViewBuilder
    private func parentGroupView(_ parent: GroupSection) -> some View {
        DisclosureGroup(isExpanded: expansionBinding(for: parent.id)) {
            if parent.entries.isEmpty {
                Text("该分组内暂无数据")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                        moveDroppedEntry(
                            providers: providers,
                            toCategory: parent.key,
                            before: nil
                        )
                    }
            } else {
                entryRows(parent.entries)
            }
        } label: {
            Text(parent.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .onDrop(
                    of: [UTType.text],
                    isTargeted: nil
                ) { providers in
                    moveDroppedEntry(
                        providers: providers,
                        toCategory: parent.key,
                        before: nil
                    )
                }
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .contentShape(Rectangle())
        .accessibilityLabel(parent.name)
    }

    @ViewBuilder
    private func entryRows(_ values: [PasswordEntry]) -> some View {
        ForEach(values, id: \.id) { entry in
            VStack(spacing: 0) {
                Button {
                    editingEntry = entry
                } label: {
                    HStack(spacing: 12) {
                        EntryRowView(entry: entry)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityHint("点击编辑密码")

            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .listRowSeparator(.hidden)
            .onDrag {
                NSItemProvider(object: NSString(string: entry.id.uuidString))
            }
            .onDrop(
                of: [UTType.text],
                isTargeted: nil
            ) { providers in
                moveDroppedEntry(
                    providers: providers,
                    toCategory: entry.category,
                    before: entry.id
                )
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

    private func moveDroppedEntry(
        providers: [NSItemProvider],
        toCategory: String?,
        before beforeID: UUID?
    ) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            let string: String?
            if let object = object as? String {
                string = object
            } else if let object = object as? NSString {
                string = object as String
            } else {
                string = nil
            }
            guard let string, let sourceID = UUID(uuidString: string) else { return }
            DispatchQueue.main.async {
                self.moveEntry(sourceID, toCategory: toCategory, beforeID: beforeID)
            }
        }
        return true
    }

    private func expansionBinding(for key: String) -> Binding<Bool> {
        Binding(
            get: { !collapsedGroupKeys.contains(key) },
            set: { isExpanded in
                if isExpanded {
                    collapsedGroupKeys.remove(key)
                } else {
                    collapsedGroupKeys.insert(key)
                }
            }
        )
    }

    private func compareForSortOrder(_ lhs: PasswordEntry, _ rhs: PasswordEntry) -> Bool {
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }

        let lhsUpdated = lhs.lastUsedAt ?? lhs.updatedAt
        let rhsUpdated = rhs.lastUsedAt ?? rhs.updatedAt
        return lhsUpdated > rhsUpdated
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
