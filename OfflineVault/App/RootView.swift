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
        .simultaneousGesture(
            DragGesture(minimumDistance: 0).onChanged { _ in
                session.registerActivity()
            }
        )
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            VaultListView()
                .tabItem {
                    Label("所有密码", systemImage: "key.fill")
                }
            MineView()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
        }
    }
}
