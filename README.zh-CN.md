# Offline Vault

[English](README.md) · [中文](README.zh-CN.md)

只存在这台 iPhone 上的原生密码本。不联网，没有账号，也没有云。

面容 ID 和 App 密码可以同时开。面容 ID 是快开，App 密码是后路。

## 这是什么

Offline Vault 把登录信息存在本机。底部两个入口：

- **所有密码** — 查找、查看、复制、记下
- **我的** — 选择怎么打开 App、导出备份、清空本机数据

敏感字段用 AES-256-GCM 加密后写入 SwiftData。数据密钥不会离开这台设备。面容 ID 从钥匙串取出密钥；App 密码在本地解开同一把密钥。

## 明确不做

- 账号 / 登录
- 云同步 / iCloud
- 任何网络请求或分析
- 分享
- 浏览器自动填充扩展（第一版）

## 功能

- 两个 Tab：所有密码、我的
- 面容 ID 和 App 密码可同时开启
- 第一次使用先设 App 密码，再选择是否开面容 ID
- 进入后台立即锁定
- 搜索、右滑复制、长按菜单
- 详情页突出揭开和复制密码
- 新建时可以快速换一条密码
- 复杂密码生成器：自动生成、快捷复制、保存
- 复制后的密码 30 秒后从剪贴板清除，且不走万能剪贴板
- 加密导出 / 导入 `.vault` 备份
- 系统原生界面；iOS 26 的工具栏、Tab 和主按钮使用 Liquid Glass

## 安全设计

| 项目 | 实现 |
| --- | --- |
| App 密码 | 用 Argon2id 包装数据密钥，不以明文保存 |
| 面容 ID | LocalAuthentication + Keychain（`userPresence`，仅本机） |
| 加密 | CryptoKit AES-256-GCM，加密密码字段 |
| 会话 | 解开后的密钥只留在内存，锁定后清除 |
| 文件保护 | `NSFileProtectionComplete`，数据目录排除 iCloud 备份 |
| 剪贴板 | 30 秒过期，`localOnly` |

两个锁都关掉后，打开 App 不再验证。建议至少保留一种。需要带到别处时，再导出加密备份。

## 系统要求

- Xcode 16+（推荐 Xcode 26，以便编译 Liquid Glass）
- iOS 17.0+
- Swift 5，SwiftUI + SwiftData
- 真机才能完整测试 Face ID / Touch ID

## 本地运行

1. 用 Xcode 打开 `OfflineVault.xcodeproj`
2. 在 Signing & Capabilities 里选择你的 Development Team
3. 选模拟器或真机运行

模拟器请先打开 **Features → Face ID → Enrolled**。

```bash
xcodebuild -project OfflineVault.xcodeproj -scheme OfflineVault \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO test
```

## 项目结构

```
OfflineVault/
├── App/                 入口、根视图、Tab
├── Core/
│   ├── Crypto/          Argon2id / PBKDF2、AES-GCM、安全内存
│   ├── Auth/            App 密码、面容 ID、自动锁定
│   ├── Vault/           SwiftData 与加解密封装
│   └── Backup/          .vault 导入导出
├── Features/            锁定、列表、详情、编辑、生成器、我的
├── Shared/              原生玻璃、剪贴板
└── Vendor/argon2/       官方 PHC Argon2 源码（本地编译）
```

## 备份格式

导出文件扩展名为 `.vault`。用单独的备份密码派生密钥，再对整包 JSON 做 AES-GCM 加密。导入按条目 ID 合并，已存在的会被覆盖。这个密码只保护备份文件，不是打开 App 用的。

## 许可证

本项目使用 [MIT License](LICENSE)。

内置的 Argon2 参考实现来自 [PHC winner Argon2](https://github.com/P-H-C/phc-winner-argon2)，采用 CC0 1.0 / Apache 2.0。
