import SwiftData
import SwiftUI

@main
struct OfflineVaultApp: App {
    @State private var session: SessionController
    @State private var vaultService: VaultService?
    private let container: ModelContainer?

    init() {
        let session = SessionController()
        _session = State(initialValue: session)
        do {
            let container = try Persistence.makeContainer()
            self.container = container
            _vaultService = State(
                initialValue: VaultService(modelContext: container.mainContext, session: session)
            )
        } catch {
            self.container = nil
            _vaultService = State(initialValue: nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container, let vaultService {
                RootView()
                    .environment(session)
                    .environment(vaultService)
                    .modelContainer(container)
            } else {
                ContentUnavailableView(
                    "无法打开本地保险库",
                    systemImage: "exclamationmark.lock.fill",
                    description: Text("数据目录无法使用完整文件保护打开。")
                )
            }
        }
    }
}
