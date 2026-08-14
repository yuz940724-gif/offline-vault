# Offline Vault

[中文](#offline-vault-中文) · [English](#offline-vault-english)

完全离线的原生 iOS 密码管理器。数据只存在这台设备上，不申请网络权限，也不连接任何服务器。

A fully offline native iOS password manager. Data never leaves the device. No network permission, no servers.

---

## Offline Vault 中文

### 这是什么

Offline Vault 是一个只供本机使用的密码保险库。用主密码解锁，可选 Face ID / Touch ID。所有敏感字段在本地用 AES-256-GCM 加密后存入 SwiftData。

主密码本身不会被保存，只用来派生加密密钥。

### 明确不做

- 账号 / 登录
- 云同步 / iCloud
- 任何网络请求或分析
- 分享
- 浏览器自动填充扩展（第一版）

### 功能

- 首次设置主密码，并做强度检查
- 主密码或 Face ID / Touch ID 解锁
- 进入后台立即锁定，前台无操作超时锁定（默认 5 分钟）
- 密码条目的增删改查
- 按标题、用户名、备注搜索，收藏置顶
- 内置密码生成器
- 复制密码后 30 秒自动清除剪贴板，且不走万能剪贴板
- 加密导出 / 导入 `.vault` 备份
- iOS 26 使用 Liquid Glass，iOS 17–25 自动降级为系统材质

### 安全设计

| 项目 | 实现 |
| --- | --- |
| 主密码 | 不落盘，只用于派生密钥 |
| 密钥派生 | 默认 Argon2id（32 MiB / 3 轮）；备选 PBKDF2-HMAC-SHA256（60 万轮） |
| 加密 | CryptoKit AES-256-GCM，至少加密密码字段 |
| 生物识别 | LocalAuthentication + Keychain（`biometryCurrentSet`，仅本机） |
| 会话 | 解锁后密钥只留在内存；锁定或离开页面后尽快清除明文 |
| 文件保护 | `NSFileProtectionComplete`，数据目录排除 iCloud 备份 |
| 剪贴板 | 30 秒过期，`localOnly` |

忘记主密码无法恢复数据。请自行保管主密码，并定期导出加密备份。

### 系统要求

- Xcode 16+（推荐 Xcode 26，以便编译 Liquid Glass）
- iOS 17.0+
- Swift 5，SwiftUI + SwiftData
- 真机才能完整测试 Face ID / Touch ID

### 本地运行

1. 用 Xcode 打开 `OfflineVault.xcodeproj`
2. 在 Signing & Capabilities 里选择你的 Development Team
3. 选模拟器或真机运行

```bash
xcodebuild -project OfflineVault.xcodeproj -scheme OfflineVault \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test
```

### 项目结构

```
OfflineVault/
├── App/                 入口与根视图
├── Core/
│   ├── Crypto/          密钥派生、AES-GCM、安全内存
│   ├── Auth/            主密码、生物识别、自动锁定
│   ├── Vault/           SwiftData 与加解密封装
│   └── Backup/          .vault 导入导出
├── Features/            锁定页、列表、详情、编辑、生成器、设置
├── Shared/              玻璃材质、剪贴板
└── Vendor/argon2/       官方 PHC Argon2 源码（本地编译）
```

### 备份格式

导出文件扩展名为 `.vault`。文件内是独立备份密码派生出的密钥，再对整包 JSON 做 AES-GCM 加密。导入时按条目 ID 合并，已存在的条目会被覆盖。

### 许可证

应用源码按本仓库条款使用。内置的 Argon2 参考实现来自 [PHC winner Argon2](https://github.com/P-H-C/phc-winner-argon2)，采用 CC0 1.0 / Apache 2.0。

---

## Offline Vault English

### What it is

Offline Vault is a personal, on-device password manager for iOS. Unlock with a master password, optionally Face ID / Touch ID. Sensitive fields are encrypted with AES-256-GCM and stored locally in SwiftData.

The master password is never stored. It is only used to derive the data-encryption key.

### Out of scope

- Accounts / sign-in
- Cloud sync / iCloud
- Any network request or analytics
- Sharing
- Browser AutoFill extensions (v1)

### Features

- First-run master password setup with strength checks
- Unlock with master password or Face ID / Touch ID
- Lock immediately in the background; idle timeout while foregrounded (default 5 minutes)
- Create, read, update, and delete entries
- Search title, username, and notes; favorites stay on top
- Built-in password generator
- Copied passwords expire from the clipboard after 30 seconds and stay off Universal Clipboard
- Encrypted `.vault` backup export / import
- Liquid Glass on iOS 26; system materials on iOS 17–25

### Security

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

### Requirements

- Xcode 16+ (Xcode 26 recommended for Liquid Glass)
- iOS 17.0+
- Swift 5, SwiftUI + SwiftData
- A physical device is required to fully test Face ID / Touch ID

### Run locally

1. Open `OfflineVault.xcodeproj` in Xcode
2. Choose your Development Team under Signing & Capabilities
3. Run on a simulator or device

```bash
xcodebuild -project OfflineVault.xcodeproj -scheme OfflineVault \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test
```

### Layout

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

### Backup format

Exports use the `.vault` extension. A separate backup password derives the key, then the JSON payload is sealed with AES-GCM. Import merges by entry ID and overwrites existing matches.

### License

Application source follows this repository. Vendored Argon2 comes from [PHC winner Argon2](https://github.com/P-H-C/phc-winner-argon2) under CC0 1.0 / Apache 2.0.
