# Offline Vault

[English](README.md) · [中文](README.zh-CN.md)

A fully offline native iOS password manager. Data never leaves the device. No network permission, no servers.

## What it is

Offline Vault is a personal, on-device password manager for iOS. Unlock with a master password, optionally Face ID / Touch ID. Sensitive fields are encrypted with AES-256-GCM and stored locally in SwiftData.

The master password is never stored. It is only used to derive the data-encryption key.

## Out of scope

- Accounts / sign-in
- Cloud sync / iCloud
- Any network request or analytics
- Sharing
- Browser AutoFill extensions (v1)

## Features

- First-run master password setup with strength checks
- Unlock with master password or Face ID / Touch ID
- Lock immediately in the background; idle timeout while foregrounded (default 5 minutes)
- Create, read, update, and delete entries
- Search title, username, and notes; favorites stay on top
- Built-in password generator
- Copied passwords expire from the clipboard after 30 seconds and stay off Universal Clipboard
- Encrypted `.vault` backup export / import
- Liquid Glass on iOS 26; system materials on iOS 17–25

## Security

| Area | Implementation |
| --- | --- |
| Master password | Never persisted; used only for key derivation |
| KDF | Argon2id by default (32 MiB / 3 passes); PBKDF2-HMAC-SHA256 fallback (600,000 iterations) |
| Encryption | CryptoKit AES-256-GCM, at least for the password field |
| Biometrics | LocalAuthentication + Keychain (`biometryCurrentSet`, this device only) |
| Session | Key stays in memory after unlock; plaintext is cleared on lock or when leaving a screen |
| Files | `NSFileProtectionComplete`; vault directory excluded from iCloud backup |
| Clipboard | 30-second expiry, `localOnly` |

If you forget the master password, the data cannot be recovered. Keep the master password safe and export encrypted backups regularly.

## Requirements

- Xcode 16+ (Xcode 26 recommended for Liquid Glass)
- iOS 17.0+
- Swift 5, SwiftUI + SwiftData
- A physical device is required to fully test Face ID / Touch ID

## Run locally

1. Open `OfflineVault.xcodeproj` in Xcode
2. Choose your Development Team under Signing & Capabilities
3. Run on a simulator or device

```bash
xcodebuild -project OfflineVault.xcodeproj -scheme OfflineVault \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test
```

## Layout

```
OfflineVault/
├── App/                 App entry and root view
├── Core/
│   ├── Crypto/          Key derivation, AES-GCM, secure memory
│   ├── Auth/            Master password, biometrics, auto-lock
│   ├── Vault/           SwiftData plus encrypt/decrypt helpers
│   └── Backup/          .vault import / export
├── Features/            Lock, list, detail, editor, generator, settings
├── Shared/              Glass materials, clipboard
└── Vendor/argon2/       Official PHC Argon2 sources (compiled locally)
```

## Backup format

Exports use the `.vault` extension. A separate backup password derives the key, then the JSON payload is sealed with AES-GCM. Import merges by entry ID and overwrites existing matches.

## License

This project is released under the [MIT License](LICENSE).

Vendored Argon2 comes from [PHC winner Argon2](https://github.com/P-H-C/phc-winner-argon2) under CC0 1.0 / Apache 2.0.
