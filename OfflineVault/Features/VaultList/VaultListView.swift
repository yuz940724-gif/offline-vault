import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct VaultListView: View {
    enum Presentation {
        case vault
        case search
    }

    private struct GroupSection: Identifiable {
        let key: String?
        let name: String
        let entries: [PasswordEntry]

        var id: String { key ?? "" }
    }

    private struct GroupFilterOption: Identifiable {
        static let allID = "filter:all"

        let id: String
        let key: String?
        let name: String
        let count: Int
    }

    @Environment(VaultService.self) private var vault
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Query private var entries: [PasswordEntry]
    @Query private var groups: [PasswordGroup]

    private let presentation: Presentation
    private let externalSearchText: Binding<String>?
    private let showsInlineSearch: Bool

    @State private var localSearchText = ""
    @State private var showingEditor = false
    @State private var showingGenerator = false
    @State private var editorPrefillTitle = ""
    @State private var editingEntry: PasswordEntry?
    @State private var pendingDelete: PasswordEntry?
    @State private var banner: String?
    @State private var collapsedGroupKeys: Set<String> = []
    @State private var selectedGroupID = GroupFilterOption.allID

    init(
        presentation: Presentation = .vault,
        searchText: Binding<String>? = nil,
        showsInlineSearch: Bool = true
    ) {
        self.presentation = presentation
        self.externalSearchText = searchText
        self.showsInlineSearch = showsInlineSearch
    }

    private var searchBinding: Binding<String> {
        externalSearchText ?? $localSearchText
    }

    private var query: String {
        searchBinding.wrappedValue
    }

    private var matchingEntries: [PasswordEntry] {
        entries.filter { $0.matches(query: query) }
    }

    private var filtered: [PasswordEntry] {
        guard presentation == .vault,
              selectedGroupID != GroupFilterOption.allID,
              let filter = groupFilterOptions.first(where: { $0.id == selectedGroupID }) else {
            return matchingEntries
        }

        return matchingEntries.filter { normalizedCategory($0.category) == filter.key }
    }

    private var groupedEntries: [GroupSection] {
        let parents = Dictionary(grouping: filtered) { entry in
            normalizedCategory(entry.category) ?? ""
        }

        return parents.keys.sorted { lhs, rhs in
            if lhs.isEmpty != rhs.isEmpty {
                return !lhs.isEmpty
            }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }.map { parent in
            GroupSection(
                key: parent.isEmpty ? nil : parent,
                name: parent.isEmpty ? "未分组" : parent,
                entries: (parents[parent] ?? []).sorted(by: compareForSortOrder)
            )
        }
    }

    private var groupFilterOptions: [GroupFilterOption] {
        var categoryNames = Set<String>()

        groups.forEach { group in
            if let category = normalizedCategory(group.category) {
                categoryNames.insert(category)
            }
        }
        entries.forEach { entry in
            if let category = normalizedCategory(entry.category) {
                categoryNames.insert(category)
            }
        }

        let categories = categoryNames.sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }

        var options = [
            GroupFilterOption(
                id: GroupFilterOption.allID,
                key: nil,
                name: "全部",
                count: entries.count
            )
        ]

        options.append(contentsOf: categories.map { category in
            GroupFilterOption(
                id: "filter:group:\(category)",
                key: category,
                name: category,
                count: entries.filter { normalizedCategory($0.category) == category }.count
            )
        })

        let ungroupedCount = entries.filter { normalizedCategory($0.category) == nil }.count
        if ungroupedCount > 0 {
            options.append(
                GroupFilterOption(
                    id: "filter:ungrouped",
                    key: nil,
                    name: "未分组",
                    count: ungroupedCount
                )
            )
        }

        return options
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if presentation == .vault, !entries.isEmpty {
                    vaultOverview
                }
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(presentation == .search ? "搜索" : "所有密码")
            .modifier(
                InlineVaultSearchModifier(
                    isEnabled: showsInlineSearch,
                    text: searchBinding
                )
            )
            .toolbar {
                if presentation == .vault {
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
            .animation(reduceMotion ? nil : .snappy, value: banner)
            .task {
                do {
                    try vault.ensureGroupsFromEntries()
                } catch {
                    showBanner(error.localizedDescription)
                }
            }
            .onChange(of: groupFilterOptions.map(\.id)) { _, ids in
                if !ids.contains(selectedGroupID) {
                    selectedGroupID = GroupFilterOption.allID
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

    @ViewBuilder
    private var content: some View {
        if presentation == .search, query.isEmpty {
            searchLanding
        } else if entries.isEmpty, query.isEmpty {
            unavailableView(
                title: "保险库还是空的",
                message: "添加第一条账号，密码只会保存在这台 iPhone。",
                systemImage: "key.horizontal.fill",
                actionTitle: "记下一条"
            ) {
                editorPrefillTitle = ""
                showingEditor = true
            }
        } else if filtered.isEmpty {
            unavailableView(
                title: "没有找到结果",
                message: "没有匹配“\(query)”的名称、账号或分组。",
                systemImage: "magnifyingglass",
                actionTitle: "记下“\(query)”"
            ) {
                editorPrefillTitle = query
                showingEditor = true
            }
        } else if presentation == .search {
            searchResultsList
        } else {
            vaultList
        }
    }

    private var vaultOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label("仅保存在本机", systemImage: "iphone.gen3")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Label("不连接网络", systemImage: "wifi.slash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(groupFilterOptions) { option in
                        groupFilterChip(option)
                    }
                }
                .padding(.vertical, 1)
            }
            .contentMargins(.horizontal, 0, for: .scrollContent)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 14)
        .background(Color(uiColor: .systemGroupedBackground))
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.horizontal, 20)
        }
    }

    private func groupFilterChip(_ option: GroupFilterOption) -> some View {
        let isSelected = selectedGroupID == option.id

        return Button {
            selectedGroupID = option.id
        } label: {
            HStack(spacing: 7) {
                if option.id == GroupFilterOption.allID {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.caption)
                }
                Text(option.name)
                    .font(.subheadline.weight(.semibold))
                Text("\(option.count)")
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        isSelected ? Color.white.opacity(0.2) : Color.primary.opacity(0.07),
                        in: Capsule()
                    )
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 13)
            .frame(height: 38)
            .background(
                isSelected ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground),
                in: Capsule()
            )
            .overlay {
                if !isSelected {
                    Capsule()
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                }
            }
        }
        .buttonStyle(VaultPressButtonStyle(scale: 0.97))
        .accessibilityLabel("\(option.name)，\(option.count) 项")
        .accessibilityValue(isSelected ? "已选择" : "")
    }

    private var vaultList: some View {
        List {
            ForEach(groupedEntries) { parent in
                Section {
                    if !collapsedGroupKeys.contains(parent.id) {
                        entryRows(parent.entries, showsGroup: false)
                    }
                } header: {
                    groupHeaderRow(parent)
                }
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(.custom(18))
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var searchResultsList: some View {
        List {
            Section {
                entryRows(filtered.sorted(by: compareForSortOrder), showsGroup: true)
            } header: {
                HStack {
                    Text("搜索结果")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(filtered.count) 项")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .textCase(nil)
                .padding(.horizontal, 4)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var searchLanding: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 14) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 72, height: 72)
                        .background(Color.accentColor.opacity(0.12), in: Circle())

                    Text("搜索本机密码")
                        .font(.title2.bold())

                    Text("可以搜索名称、账号、网址、备注或分组。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 48)

                if groupFilterOptions.count > 1 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("按分组查找")
                            .font(.headline)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(groupFilterOptions.dropFirst()) { option in
                                    Button {
                                        searchBinding.wrappedValue = option.name
                                    } label: {
                                        Label(option.name, systemImage: "folder.fill")
                                            .font(.subheadline.weight(.semibold))
                                            .padding(.horizontal, 14)
                                            .frame(height: 42)
                                            .background(
                                                Color(uiColor: .secondarySystemGroupedBackground),
                                                in: Capsule()
                                            )
                                            .overlay {
                                                Capsule()
                                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                            }
                                    }
                                    .buttonStyle(VaultPressButtonStyle(scale: 0.97))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
    }

    private func unavailableView(
        title: String,
        message: String,
        systemImage: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 68, height: 68)
                .background(Color.accentColor.opacity(0.12), in: Circle())
            VStack(spacing: 7) {
                Text(title)
                    .font(.title3.bold())
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button(actionTitle, action: action)
                .nativeProminentButton()
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func copyUsername(_ entry: PasswordEntry) {
        guard !entry.username.isEmpty else {
            showBanner("账号为空")
            return
        }
        ClipboardService.copyText(entry.username)
        Haptics.success()
        showBanner("已复制账号")
    }

    private func copyPassword(_ entry: PasswordEntry) {
        do {
            _ = try vault.copyPassword(entry)
            Haptics.success()
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

    private func groupHeaderRow(_ parent: GroupSection) -> some View {
        let isExpanded = !collapsedGroupKeys.contains(parent.id)

        return Button {
            let update = {
                if isExpanded {
                    collapsedGroupKeys.insert(parent.id)
                } else {
                    collapsedGroupKeys.remove(parent.id)
                }
            }
            if reduceMotion {
                update()
            } else {
                withAnimation(.snappy(duration: 0.22, extraBounce: 0)) {
                    update()
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: parent.key == nil ? "tray.fill" : "folder.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Text(parent.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("\(parent.entries.count)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(VaultPressButtonStyle(scale: 0.985))
        .textCase(nil)
        .onDrop(of: [UTType.text], isTargeted: nil) { providers in
            moveDroppedEntry(
                providers: providers,
                toCategory: parent.key,
                before: nil
            )
        }
        .accessibilityLabel("\(parent.name)，\(parent.entries.count) 项")
        .accessibilityValue(isExpanded ? "已展开" : "已收起")
        .accessibilityHint(isExpanded ? "点击收起分组" : "点击展开分组")
    }

    @ViewBuilder
    private func entryRows(_ values: [PasswordEntry], showsGroup: Bool) -> some View {
        ForEach(values, id: \.id) { entry in
            entryCard(entry, showsGroup: showsGroup)
                .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                .listRowBackground(Color.clear)
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
                        Label("复制密码", systemImage: "key")
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
                            copyUsername(entry)
                        }
                    }
                    Button("编辑", systemImage: "pencil") {
                        editingEntry = entry
                    }
                }
        }
    }

    private func entryCard(_ entry: PasswordEntry, showsGroup: Bool) -> some View {
        VStack(spacing: 0) {
            Button {
                editingEntry = entry
            } label: {
                HStack(spacing: 14) {
                    entryMonogram(entry)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(entry.title.isEmpty ? "未命名" : entry.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if entry.isFavorite {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                            }
                        }

                        if !entry.username.isEmpty {
                            Text(entry.username)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else {
                            Text("未填写账号")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }

                        if showsGroup {
                            Label(normalizedCategory(entry.category) ?? "未分组", systemImage: "folder")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(VaultPressButtonStyle(scale: 0.985))
            .accessibilityLabel(entryAccessibilityLabel(entry))
            .accessibilityHint("点击编辑密码")

            Divider()
                .padding(.leading, 72)

            HStack(spacing: 10) {
                quickCopyButton(
                    title: "复制账号",
                    systemImage: "person.crop.circle",
                    color: .indigo,
                    isEnabled: !entry.username.isEmpty
                ) {
                    copyUsername(entry)
                }

                quickCopyButton(
                    title: "复制密码",
                    systemImage: "key.fill",
                    color: .accentColor,
                    isEnabled: true
                ) {
                    copyPassword(entry)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.05), lineWidth: 1)
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.14 : 0.045),
            radius: 12,
            x: 0,
            y: 5
        )
    }

    private func entryMonogram(_ entry: PasswordEntry) -> some View {
        let title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let monogram = title.isEmpty ? "?" : String(title.prefix(1)).uppercased()
        let color = monogramColor(for: title)

        return Text(monogram)
            .font(.title3.bold())
            .foregroundStyle(color)
            .frame(width: 44, height: 44)
            .background(
                color.opacity(0.14),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .accessibilityHidden(true)
    }

    private func quickCopyButton(
        title: String,
        systemImage: String,
        color: Color,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isEnabled ? color : Color.secondary.opacity(0.45))
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(color.opacity(isEnabled ? 0.1 : 0.04), in: Capsule())
        }
        .buttonStyle(VaultPressButtonStyle(scale: 0.97))
        .disabled(!isEnabled)
        .accessibilityLabel(title)
    }

    private func monogramColor(for title: String) -> Color {
        let palette: [Color] = [.blue, .indigo, .purple, .teal, .orange, .pink]
        let value = title.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[value % palette.count]
    }

    private func entryAccessibilityLabel(_ entry: PasswordEntry) -> String {
        let title = entry.title.isEmpty ? "未命名" : entry.title
        return entry.username.isEmpty ? title : "\(title)，\(entry.username)"
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

    private func normalizedCategory(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
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

private struct InlineVaultSearchModifier: ViewModifier {
    let isEnabled: Bool
    @Binding var text: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.searchable(
                text: $text,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "搜索名称、账号或分组"
            )
        } else {
            content
        }
    }
}

private struct VaultPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let scale: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}
