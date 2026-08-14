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
        case locked
        case unlocked
    }

    private(set) var phase: Phase = .launching
    private(set) var biometricKind: BiometricKind = .none
    private(set) var isBiometricsEnabled = false
    private(set) var lastError: String?

    let autoLock = AutoLockController()

    private var dataKey: SymmetricKey?

    var isUnlocked: Bool { phase == .unlocked }

    func currentDataKey() throws -> SymmetricKey {
        guard let dataKey, phase == .unlocked else {
            throw AuthError.locked
        }
        return dataKey
    }

    func bootstrap() {
        biometricKind = BiometricUnlock.availableKind()
        isBiometricsEnabled = KeychainStore.exists()
        phase = VaultConfigurationStore.exists() ? .locked : .needsSetup
    }

    func setupMasterPassword(_ password: String, confirmation: String, enableBiometrics: Bool) async throws {
        guard !VaultConfigurationStore.exists() else { throw AuthError.alreadyInitialized }
        guard password == confirmation else { throw AuthError.passwordMismatch }
        guard PasswordStrengthEvaluator.evaluate(password).isAcceptableForMasterPassword else {
            throw AuthError.passwordTooWeak
        }

        let (configuration, key) = try await deriveNewConfiguration(password: password)
        try VaultConfigurationStore.save(configuration)
        if enableBiometrics {
            try storeBiometricKey(key)
        }
        activate(key: key)
    }

    func unlockWithMasterPassword(_ password: String) async throws {
        let configuration = try VaultConfigurationStore.load()
        let key = try await Task.detached(priority: .userInitiated) {
            try KeyDerivation.derive(password: password, parameters: configuration.parameters)
        }.value

        do {
            try configuration.verify(key)
        } catch {
            throw AuthError.incorrectPassword
        }
        activate(key: key)
    }

    func unlockWithBiometrics() async throws {
        guard isBiometricsEnabled else { throw AuthError.biometricsNotEnabled }
        guard biometricKind != .none else { throw AuthError.biometricsUnavailable }

        let reason = "解锁 Offline Vault"
        let context = BiometricUnlock.makeContext(reason: reason)
        let success = try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
        guard success else { throw AuthError.biometricsFailed }

        let key = try KeychainStore.loadProtectedKey(context: context)
        try VaultConfigurationStore.load().verify(key)
        activate(key: key)
    }

    func lock() {
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

    func enableBiometricsAfterUnlock() throws {
        let key = try currentDataKey()
        try storeBiometricKey(key)
    }

    func disableBiometrics() throws {
        try KeychainStore.delete()
        isBiometricsEnabled = false
    }

    func prepareMasterPasswordChange(
        current: String,
        new: String,
        confirmation: String
    ) async throws -> (oldKey: SymmetricKey, newKey: SymmetricKey, configuration: VaultConfiguration) {
        guard new == confirmation else { throw AuthError.passwordMismatch }
        guard PasswordStrengthEvaluator.evaluate(new).isAcceptableForMasterPassword else {
            throw AuthError.passwordTooWeak
        }

        let currentConfiguration = try VaultConfigurationStore.load()
        let currentKey = try await Task.detached(priority: .userInitiated) {
            try KeyDerivation.derive(password: current, parameters: currentConfiguration.parameters)
        }.value
        do {
            try currentConfiguration.verify(currentKey)
        } catch {
            throw AuthError.incorrectPassword
        }

        let (newConfiguration, newKey) = try await deriveNewConfiguration(password: new)
        return (currentKey, newKey, newConfiguration)
    }

    func commitMasterPasswordChange(newKey: SymmetricKey, configuration: VaultConfiguration) throws {
        try VaultConfigurationStore.save(configuration)
        if isBiometricsEnabled {
            try storeBiometricKey(newKey)
        }
        activate(key: newKey)
    }

    private func deriveNewConfiguration(password: String) async throws -> (VaultConfiguration, SymmetricKey) {
        try await Task.detached(priority: .userInitiated) {
            try VaultConfiguration.create(masterPassword: password)
        }.value
    }

    private func storeBiometricKey(_ key: SymmetricKey) throws {
        guard biometricKind != .none else { throw AuthError.biometricsUnavailable }
        try KeychainStore.saveProtectedKey(key)
        isBiometricsEnabled = true
    }

    private func activate(key: SymmetricKey) {
        dataKey = key
        phase = .unlocked
        lastError = nil
        autoLock.start { [weak self] in
            self?.lock()
        }
    }
}

extension Notification.Name {
    static let vaultDidLock = Notification.Name("offline.vault.didLock")
}
