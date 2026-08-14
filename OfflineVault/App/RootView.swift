import SwiftUI

struct RootView: View {
    @Environment(SessionController.self) private var session
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch session.phase {
            case .launching:
                ProgressView("正在准备保险库")
                    .task { session.bootstrap() }
            case .needsSetup:
                SetupVaultView()
            case .locked:
                LockScreenView()
            case .unlocked:
                VaultListView()
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
