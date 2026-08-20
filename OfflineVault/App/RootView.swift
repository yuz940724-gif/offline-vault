import SwiftUI

struct RootView: View {
    @Environment(SessionController.self) private var session
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch session.phase {
            case .launching:
                ProgressView()
                    .task { session.bootstrap() }
            case .needsSetup:
                SetupVaultView()
            case .needsMigration:
                MigrationView()
            case .locked:
                LockScreenView()
            case .unlocked:
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: session.phase)
        .onChange(of: scenePhase) { _, phase in
            session.handleScenePhase(phase)
        }
    }
}

struct MainTabView: View {
    @State private var searchText = ""

    var body: some View {
        if #available(iOS 26.0, *) {
            modernTabView
        } else {
            legacyTabView
        }
    }

    @available(iOS 26.0, *)
    private var modernTabView: some View {
        TabView {
            Tab("所有密码", systemImage: "key") {
                VaultListView(showsInlineSearch: false)
            }

            Tab("我的", systemImage: "person") {
                MineView()
            }

            Tab(role: .search) {
                VaultListView(
                    presentation: .search,
                    searchText: $searchText,
                    showsInlineSearch: false
                )
                .searchable(text: $searchText, prompt: "搜索名称、账号或分组")
            }
        }
        .tabViewSearchActivation(.searchTabSelection)
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    private var legacyTabView: some View {
        TabView {
            VaultListView()
                .tabItem {
                    Label("所有密码", systemImage: "key")
                }
            MineView()
                .tabItem {
                    Label("我的", systemImage: "person")
                }
        }
    }
}
