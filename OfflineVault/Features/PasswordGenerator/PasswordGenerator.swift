import Foundation

struct PasswordGeneratorOptions: Equatable, Sendable {
    var length: Int = 20
    var uppercase: Bool = true
    var lowercase: Bool = true
    var digits: Bool = true
    var symbols: Bool = true
    var excludeAmbiguous: Bool = true

    static let lengthRange = 8...64

    var hasAnyCharacterSet: Bool {
        uppercase || lowercase || digits || symbols
    }
}

enum PasswordGenerator {
    private static let upper = Array("ABCDEFGHJKLMNPQRSTUVWXYZ")
    private static let upperAmbiguous = Array("IO")
    private static let lower = Array("abcdefghijkmnopqrstuvwxyz")
    private static let lowerAmbiguous = Array("l")
    private static let digits = Array("23456789")
    private static let digitsAmbiguous = Array("01")
    private static let symbols = Array("!@#$%^&*()-_=+[]{}:,.?")
    private static let symbolsAmbiguous = Array("|<>/\\;\"'`~")

    static func generate(_ options: PasswordGeneratorOptions) throws -> String {
        var options = options
        options.length = min(max(options.length, PasswordGeneratorOptions.lengthRange.lowerBound),
                             PasswordGeneratorOptions.lengthRange.upperBound)
        guard options.hasAnyCharacterSet else {
            throw CryptoError.invalidParameters
        }

        var pools: [[Character]] = []
        if options.uppercase { pools.append(set(upper, extra: upperAmbiguous, includeAmbiguous: !options.excludeAmbiguous)) }
        if options.lowercase { pools.append(set(lower, extra: lowerAmbiguous, includeAmbiguous: !options.excludeAmbiguous)) }
        if options.digits { pools.append(set(digits, extra: digitsAmbiguous, includeAmbiguous: !options.excludeAmbiguous)) }
        if options.symbols { pools.append(set(symbols, extra: symbolsAmbiguous, includeAmbiguous: !options.excludeAmbiguous)) }

        let alphabet = pools.flatMap { $0 }
        guard !alphabet.isEmpty else { throw CryptoError.invalidParameters }

        var characters: [Character] = []
        characters.reserveCapacity(options.length)

        for pool in pools {
            characters.append(try randomCharacter(from: pool))
        }

        while characters.count < options.length {
            characters.append(try randomCharacter(from: alphabet))
        }

        return String(try shuffle(characters))
    }

    private static func set(_ base: [Character], extra: [Character], includeAmbiguous: Bool) -> [Character] {
        includeAmbiguous ? base + extra : base
    }

    private static func randomCharacter(from pool: [Character]) throws -> Character {
        let index = try randomIndex(upperBound: pool.count)
        return pool[index]
    }

    private static func shuffle(_ input: [Character]) throws -> [Character] {
        var items = input
        guard items.count > 1 else { return items }
        for i in stride(from: items.count - 1, through: 1, by: -1) {
            let j = try randomIndex(upperBound: i + 1)
            items.swapAt(i, j)
        }
        return items
    }

    private static func randomIndex(upperBound: Int) throws -> Int {
        precondition(upperBound > 0)
        var bytes = try SecureMemory.randomBytes(count: 4)
        defer { SecureMemory.zero(&bytes) }
        let value = bytes.withUnsafeBytes { $0.load(as: UInt32.self) }
        return Int(value % UInt32(upperBound))
    }
}
