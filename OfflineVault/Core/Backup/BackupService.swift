import CryptoKit
import Foundation
import UniformTypeIdentifiers

enum BackupError: Error, Equatable, LocalizedError {
    case invalidFile
    case unsupportedVersion
    case incorrectPassword
    case emptyVault

    var errorDescription: String? {
        switch self {
        case .invalidFile:
            return "不是有效的 .vault 备份文件"
        case .unsupportedVersion:
            return "备份文件版本不受支持"
        case .incorrectPassword:
            return "备份密码不正确"
        case .emptyVault:
            return "没有可导出的条目"
        }
    }
}

struct BackupPayload: Codable, Equatable {
    static let format = "offline-vault-backup"

    var format: String
    var version: Int
    var exportedAt: Date
    var entries: [Entry]

    struct Entry: Codable, Equatable, Identifiable {
        var id: UUID
        var title: String
        var username: String
        var password: String
        var url: String?
        var notes: String?
        var isFavorite: Bool
        var category: String?
        var createdAt: Date
        var updatedAt: Date
    }
}

enum BackupService {
    static let fileExtension = "vault"
    static let magic = Data("OVL1".utf8)
    static let currentVersion: UInt16 = 1

    struct Header: Codable, Equatable {
        var kdf: KeyDerivationParameters
        var createdAt: Date
    }

    static func export(
        entries: [PasswordEntry],
        decryptPassword: (PasswordEntry) throws -> String,
        password: String,
        parameters: KeyDerivationParameters? = nil
    ) throws -> Data {
        guard !entries.isEmpty else { throw BackupError.emptyVault }

        let payload = BackupPayload(
            format: BackupPayload.format,
            version: 1,
            exportedAt: Date(),
            entries: try entries.map { entry in
                BackupPayload.Entry(
                    id: entry.id,
                    title: entry.title,
                    username: entry.username,
                    password: try decryptPassword(entry),
                    url: entry.url,
                    notes: entry.notes,
                    isFavorite: entry.isFavorite,
                    category: entry.category,
                    createdAt: entry.createdAt,
                    updatedAt: entry.updatedAt
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let plaintext = try encoder.encode(payload)

        let parameters = try parameters ?? KeyDerivationParameters.makeDefault(algorithm: .argon2id)
        let key = try KeyDerivation.derive(password: password, parameters: parameters)
        let ciphertext = try AESGCMCipher.encrypt(plaintext, key: key)
        let header = Header(kdf: parameters, createdAt: Date())
        let headerData = try encoder.encode(header)

        var file = Data()
        file.append(magic)
        file.append(Self.encodeUInt16(currentVersion))
        file.append(Self.encodeUInt32(UInt32(headerData.count)))
        file.append(headerData)
        file.append(ciphertext)
        return file
    }

    static func importData(_ data: Data, password: String) throws -> BackupPayload {
        let parsed = try parse(data)
        let key = try KeyDerivation.derive(password: password, parameters: parsed.header.kdf)
        let plaintext: Data
        do {
            plaintext = try AESGCMCipher.decrypt(parsed.ciphertext, key: key)
        } catch {
            throw BackupError.incorrectPassword
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(BackupPayload.self, from: plaintext)
        guard payload.format == BackupPayload.format else {
            throw BackupError.invalidFile
        }
        return payload
    }

    static func parse(_ data: Data) throws -> (header: Header, ciphertext: Data) {
        let prefix = magic.count + 2 + 4
        guard data.count > prefix, data.prefix(magic.count) == magic else {
            throw BackupError.invalidFile
        }

        let version = decodeUInt16(data, offset: magic.count)
        guard version == currentVersion else {
            throw BackupError.unsupportedVersion
        }

        let headerLength = Int(decodeUInt32(data, offset: magic.count + 2))
        let headerStart = prefix
        let headerEnd = headerStart + headerLength
        guard headerLength > 0, data.count > headerEnd else {
            throw BackupError.invalidFile
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let header = try decoder.decode(Header.self, from: data.subdata(in: headerStart..<headerEnd))
        let ciphertext = data.suffix(from: headerEnd)
        return (header, Data(ciphertext))
    }

    private static func encodeUInt16(_ value: UInt16) -> Data {
        var be = value.bigEndian
        return Data(bytes: &be, count: 2)
    }

    private static func encodeUInt32(_ value: UInt32) -> Data {
        var be = value.bigEndian
        return Data(bytes: &be, count: 4)
    }

    private static func decodeUInt16(_ data: Data, offset: Int) -> UInt16 {
        let bytes = Array(data[offset..<(offset + 2)])
        return UInt16(bytes[0]) << 8 | UInt16(bytes[1])
    }

    private static func decodeUInt32(_ data: Data, offset: Int) -> UInt32 {
        let bytes = Array(data[offset..<(offset + 4)])
        return UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
    }
}

extension UTType {
    static var vaultBackup: UTType {
        UTType(exportedAs: "com.offlinevault.backup")
    }
}
