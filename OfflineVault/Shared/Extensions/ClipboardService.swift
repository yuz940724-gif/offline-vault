import Foundation
import UniformTypeIdentifiers
import UIKit

enum ClipboardService {
    static let secretTTL: TimeInterval = 30
    static let copiedSecretMessage = "密码已复制，30 秒后清除"

    static func copySecret(_ value: String, ttl: TimeInterval = secretTTL) {
        UIPasteboard.general.setItems(
            [[UTType.utf8PlainText.identifier: value]],
            options: [
                .expirationDate: Date().addingTimeInterval(ttl),
                .localOnly: true
            ]
        )
        Haptics.success()
    }

    static func copyText(_ value: String) {
        UIPasteboard.general.setItems(
            [[UTType.utf8PlainText.identifier: value]],
            options: [.localOnly: true]
        )
        Haptics.success()
    }
}
