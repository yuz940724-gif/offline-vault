import Foundation
import SwiftUI

@MainActor
@Observable
final class AutoLockController {
    static let defaultTimeout: TimeInterval = 5 * 60
    static let timeoutOptions: [TimeInterval] = [60, 120, 300, 600, 900, 1800]

    var timeout: TimeInterval {
        didSet {
            UserDefaults.standard.set(timeout, forKey: Keys.timeout)
        }
    }

    private(set) var lastActivityAt = Date()
    private var timer: Timer?

    private enum Keys {
        static let timeout = "autoLockTimeout"
    }

    init() {
        let stored = UserDefaults.standard.double(forKey: Keys.timeout)
        timeout = stored > 0 ? stored : Self.defaultTimeout
    }

    func registerActivity() {
        lastActivityAt = Date()
    }

    func start(onFire: @escaping () -> Void) {
        stop()
        registerActivity()
        let timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if Date().timeIntervalSince(self.lastActivityAt) >= self.timeout {
                    onFire()
                }
            }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func shouldLock(for scenePhase: ScenePhase) -> Bool {
        scenePhase == .active && hasTimedOut
    }

    var hasTimedOut: Bool {
        Date().timeIntervalSince(lastActivityAt) >= timeout
    }

    static func timeoutTitle(_ timeout: TimeInterval) -> String {
        let minutes = Int(timeout / 60)
        return "\(minutes) 分钟"
    }
}
