import Foundation

struct VaultState: Codable, Equatable, Sendable {
    static let currentVersion = 2

    var version: Int
    var createdAt: Date

    static func makeNew() -> VaultState {
        VaultState(version: currentVersion, createdAt: Date())
    }
}

enum VaultStateStore {
    static var fileURL: URL {
        Persistence.vaultDirectory().appending(path: "vault-state.json")
    }

    static func exists() -> Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    static func save(_ state: VaultState) throws {
        let data = try JSONEncoder().encode(state)
        try data.write(to: fileURL, options: [.atomic])
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: fileURL.path
        )
    }

    static func delete() throws {
        guard exists() else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}

enum VaultConfigurationStore {
    static var fileURL: URL {
        Persistence.vaultDirectory().appending(path: "vault-config.json")
    }

    static func exists() -> Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    static func load() throws -> VaultConfiguration {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw AuthError.vaultNotInitialized
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(VaultConfiguration.self, from: data)
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.configurationCorrupted
        }
    }

    static func delete() throws {
        guard exists() else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
