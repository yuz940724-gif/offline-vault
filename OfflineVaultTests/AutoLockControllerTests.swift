import SwiftUI
import XCTest
@testable import OfflineVault

@MainActor
final class AutoLockControllerTests: XCTestCase {
    func testActiveSceneUsesTimeoutAndBackgroundDoesNotForceImmediateLock() {
        let controller = AutoLockController()
        controller.timeout = 0
        controller.registerActivity()

        XCTAssertTrue(controller.hasTimedOut)
        XCTAssertFalse(controller.shouldLock(for: .background))
        XCTAssertTrue(controller.shouldLock(for: .active))
    }

    func testTimeoutOptionsIncludeFiveMinutes() {
        XCTAssertTrue(AutoLockController.timeoutOptions.contains(5 * 60))
        XCTAssertEqual(AutoLockController.timeoutTitle(5 * 60), "5 分钟")
    }
}
