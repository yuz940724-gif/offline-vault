import Foundation
import UniformTypeIdentifiers
import UIKit

enum ClipboardService {
    static let secretTTL: TimeInterval = 30

    static func copySecret(_ value: String, ttl: TimeInterval = secretTTL) {
        UIPasteboard.general.setItems(
            [[UTType.utf8PlainText.identifier: value]],
            options: [
                .expirationDate: Date().addingTimeInterval(ttl),
                .localOnly: true
            ]
        )
    }

    static func copyText(_ value: String) {
        UIPasteboard.general.setItems(
            [[UTType.utf8PlainText.identifier: value]],
            options: [.localOnly: true]
        )
    }
}
