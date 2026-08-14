import CryptoKit
import Foundation
import LocalAuthentication
import SwiftUI

@MainActor
@Observable
final class SessionController {
    enum Phase: Equatable {
        case launching
        case needsSetup
        case needsMigration
        case locked
        case unlocked
    }

    private(set) var phase: Phase = .launching
    private(set) var biometricKind: BiometricKind = .none
    private(set) var isFaceIDEnabled = false
    private(set) var isAppPasswordEnabled = false

    let autoLock = AutoLockController()

    private var dataKey: SymmetricKey?

    var isUnlocked: Bool { phase == .unlocked }

    var canUseFaceID: Bool {
        BiometricUnlock.canProtectApp() && biometricKind != .none
    }

    var hasAnyLock: Bool {
        isFaceIDEnabled || isAppPasswordEnabled
    }

    func currentDataKey() throws -> SymmetricKey {
        guard let dataKey, phase == .unlocked else {
            throw AuthError.locked
        }
        return dataKey
    }

    func bootstrap() {
        biometricKind = BiometricUnlock.availableKind()
        isFaceIDEnabled = KeychainStore.biometricExists()
        isAppPasswordEnabled = AppPasswordStore.exists()

        if VaultConfigurationStore.exists() && !VaultStateStore.exists() && !hasAnyLock && !KeychainStore.openExists() {
            phase = .needsMigration
            return
        }

        let initialized = VaultStateStore.exists() || hasAnyLock || KeychainStore.openExists()
        if !initialized {
            phase = .needsSetup
            return
        }

        if hasAnyLock {
            phase = .locked
        } else if let key = try? KeychainStore.loadOpenKey() {
            activate(key: key)
        } else {
            phase = .needsSetup
        }
    }

    func completeFirstRun(appPassword: String, confirmation: String, enableFaceID: Bool) async throws {
        guard phase == .needsSetup else { throw AuthError.alreadyInitialized }
        guard appPassword == confirmation else { throw AuthError.passwordMismatch }
        guard PasswordStrengthEvaluator.evaluate(appPassword).isAcceptableForMasterPassword else {
            throw AuthError.passwordTooWeak
        }

        let key = SymmetricKey(size: .bits256)
        try await Task.detached(priority: .userInitiated) {
            try AppPasswordStore.wrap(key: key, password: appPassword)
        }.value
        isAppPasswordEnabled = true

        if enableFaceID {
            guard canUseFaceID else { throw AuthError.biometricsUnavailable }
            _ = try await authenticateFaceID()
            try KeychainStore.saveBiometricKey(key)
            isFaceIDEnabled = true
        }

        try VaultStateStore.save(.makeNew())
        try KeychainStore.deleteOpenKey()
        activate(key: key)
    }

    func unlockWithFaceID() async throws {
        guard isFaceIDEnabled else { throw AuthError.biometricsUnavailable }
        let context = BiometricUnlock.makeContext()
        let key = try KeychainStore.loadBiometricKey(context: context)
        activate(key: key)
    }

    func unlockWithAppPassword(_ password: String) async throws {
        guard isAppPasswordEnabled else { throw AuthError.vaultNotInitialized }
        let key = try await Task.detached(priority: .userInitiated) {
            try AppPasswordStore.unwrap(password: password)
        }.value
        activate(key: key)
    }

    func migrateFromMasterPassword(_ password: String) async throws {
        let configuration = try VaultConfigurationStore.load()
        let key = try await Task.detached(priority: .userInitiated) {
            try KeyDerivation.derive(password: password, parameters: configuration.parameters)
        }.value
        do {
            try configuration.verify(key)
        } catch {
            throw AuthError.incorrectPassword
        }

        try AppPasswordStore.wrap(key: key, password: password)
        isAppPasswordEnabled = true
        if canUseFaceID {
            try? KeychainStore.saveBiometricKey(key)
            isFaceIDEnabled = KeychainStore.biometricExists()
        }
        try VaultStateStore.save(.makeNew())
        try VaultConfigurationStore.delete()
        try KeychainStore.deleteOpenKey()
        activate(key: key)
    }

    func enableAppPassword(_ password: String, confirmation: String) async throws {
        let key = try currentDataKey()
        guard password == confirmation else { throw AuthError.passwordMismatch }
        guard PasswordStrengthEvaluator.evaluate(password).isAcceptableForMasterPassword else {
            throw AuthError.passwordTooWeak
        }
        try await Task.detached(priority: .userInitiated) {
            try AppPasswordStore.wrap(key: key, password: password)
        }.value
        isAppPasswordEnabled = true
        try persistUnlockedKeyIfNeeded(key)
    }

    func disableAppPassword(current: String) async throws {
        _ = try await Task.detached(priority: .userInitiated) {
            try AppPasswordStore.unwrap(password: current)
        }.value
        try AppPasswordStore.delete()
        isAppPasswordEnabled = false
        try persistUnlockedKeyIfNeeded(try currentDataKey())
    }

    func enableFaceID() async throws {
        let key = try currentDataKey()
        guard canUseFaceID else { throw AuthError.biometricsUnavailable }
        _ = try await authenticateFaceID()
        try KeychainStore.saveBiometricKey(key)
        isFaceIDEnabled = true
        try persistUnlockedKeyIfNeeded(key)
    }

    func disableFaceID() throws {
        let key = try currentDataKey()
        try KeychainStore.deleteBiometricKey()
        isFaceIDEnabled = false
        try persistUnlockedKeyIfNeeded(key)
    }

    func lock() {
        guard hasAnyLock else { return }
        dataKey = nil
        autoLock.stop()
        if phase == .unlocked {
            phase = .locked
        }
        NotificationCenter.default.post(name: .vaultDidLock, object: nil)
    }

    func handleScenePhase(_ scenePhase: ScenePhase) {
        guard phase == .unlocked else { return }
        if autoLock.shouldLock(for: scenePhase) {
            lock()
        }
    }

    func registerActivity() {
        guard phase == .unlocked else { return }
        autoLock.registerActivity()
    }

    func resetLocalUnlock() throws {
        dataKey = nil
        autoLock.stop()
        try KeychainStore.deleteAll()
        try AppPasswordStore.delete()
        try VaultStateStore.delete()
        try VaultConfigurationStore.delete()
        isFaceIDEnabled = false
        isAppPasswordEnabled = false
        phase = .needsSetup
        NotificationCenter.default.post(name: .vaultDidLock, object: nil)
    }

    private func persistUnlockedKeyIfNeeded(_ key: SymmetricKey) throws {
        if hasAnyLock {
            try KeychainStore.deleteOpenKey()
        } else {
            try KeychainStore.saveOpenKey(key)
        }
    }

    private func authenticateFaceID() async throws -> LAContext {
        guard canUseFaceID else { throw AuthError.biometricsUnavailable }
        let context = BiometricUnlock.makeContext()
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: BiometricUnlock.reason
            )
            guard success else { throw AuthError.biometricsFailed }
            return context
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.biometricsFailed
        }
    }

    private func activate(key: SymmetricKey) {
        dataKey = key
        phase = .unlocked
        autoLock.start { [weak self] in
            self?.lock()
        }
    }
}

extension Notification.Name {
    static let vaultDidLock = Notification.Name("offline.vault.didLock")
}
