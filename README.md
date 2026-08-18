# Offline Vault

[English](README.md) · [中文](README.zh-CN.md)

A native iOS password book that stays on this iPhone. No network, no account, no cloud.

Unlock with Face ID and an App password at the same time. Face ID is the fast path; the App password is the fallback.

## What it is

Offline Vault stores your logins on device. There are two tabs:

- **All Passwords** — browse by two-level groups, view, copy, edit, and save entries
- **Me** — choose how the app unlocks, export backups, erase local data

Sensitive fields are encrypted with AES-256-GCM and saved in SwiftData. The data-encryption key never leaves the device. Face ID reads it from the Keychain. The App password unwraps a local copy of the same key.

## Out of scope

- Accounts / sign-in
- Cloud sync / iCloud
- Any network request or analytics
- Password sharing (device migration uses encrypted backups)
- Browser AutoFill extensions (v1)

## Features

- Two-tab app: All Passwords and Me
- Face ID and App password can be on together
- First launch sets an App password, then optionally Face ID
- Lock after the selected idle period, and re-check the timeout when returning to the app
- Search names, usernames, URLs, notes, and both group levels
- Detail view supports reveal, copy, and editing
- Two-level groups such as `ECS / AppStore`
- Simple refresh when adding an entry
- Full password generator: auto-generate, copy, save
- Copied secrets expire from the clipboard after 30 seconds and stay off Universal Clipboard
- Encrypted `.vault` backup export / import for AirDrop or Files-based device migration
- Native system UI, with Liquid Glass on iOS 26 toolbars, tabs, and primary actions

## Screenshots

The screenshots below are from the current `main` build running on an iPhone 17 simulator with iOS 26.5.

| All Passwords | Me |
| --- | --- |
| ![All Passwords empty state](docs/screenshots/passwords-list.jpg) | ![Me settings](docs/screenshots/me-settings.jpg) |

## Security

| Area | Implementation |
| --- | --- |
| App password | Wraps the data key with Argon2id; never stored in plaintext |
| Face ID | LocalAuthentication + Keychain (`userPresence`, this device only) |
| Encryption | CryptoKit AES-256-GCM for password fields |
| Session | Unwrapped key stays in memory; cleared on lock |
| Files | `NSFileProtectionComplete`; vault directory excluded from iCloud backup |
| Clipboard | 30-second expiry, `localOnly` |

If both unlock methods are off, the app no longer asks for verification. Keep at least one lock on. To move to a new iPhone, export an encrypted backup from the old phone and import it through AirDrop or Files on the new phone; this app has no cloud sync or automatic online migration.

## Requirements

- Xcode 16+ (Xcode 26 recommended for Liquid Glass)
- iOS 17.0+
- Swift 5, SwiftUI + SwiftData
- A physical device is required to fully test Face ID / Touch ID

## Run locally

1. Open `OfflineVault.xcodeproj` in Xcode
2. Choose your Development Team under Signing & Capabilities
3. Run on a simulator or device

On the simulator, turn on **Features → Face ID → Enrolled**.

If you forget the App password in the simulator, choose **Forgot password, enter simulator directly** on the lock screen. The first use clears the simulator's local vault and saves a development key, so later simulator launches do not ask for a password. This entry point is compiled only for Simulator and never appears on a physical device.

```bash
xcodebuild -project OfflineVault.xcodeproj -scheme OfflineVault \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test
```

## Layout

```
OfflineVault/
├── App/                 Entry, root view, tab shell
├── Core/
│   ├── Crypto/          Argon2id / PBKDF2, AES-GCM, secure memory
│   ├── Auth/            App password, Face ID, auto-lock
│   ├── Vault/           SwiftData plus encrypt/decrypt helpers
│   └── Backup/          .vault import / export
├── Features/            Lock, list, detail, editor, generator, Me
├── Shared/              Native glass helpers, clipboard
└── Vendor/argon2/       Official PHC Argon2 sources (compiled locally)
```

## Backup format

Exports use the `.vault` extension. A separate backup password derives the key, then the JSON payload is sealed with AES-GCM. Import merges by entry ID and overwrites existing matches. That password is only for the backup file, not for opening the app.

## License

This project is released under the [MIT License](LICENSE).

Vendored Argon2 comes from [PHC winner Argon2](https://github.com/P-H-C/phc-winner-argon2) under CC0 1.0 / Apache 2.0.
