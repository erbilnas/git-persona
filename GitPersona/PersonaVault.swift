import CryptoKit
import Foundation
import Security

/// AES-GCM encryption for persona persistence; symmetric key material is stored in the Keychain.
enum PersonaVault {
    private static let magic = Data("GPV1".utf8)
    private static let keychainService = "dev.gitpersona.app.persona-store"
    private static let keychainAccount = "aes256-gcm-v1"

    enum VaultError: Error {
        case keychain(OSStatus)
        case keyMissing
        case badEnvelope
        case crypto(Error)
    }

    static func encrypt(_ plaintext: Data) throws -> Data {
        let key = try materialKey()
        do {
            let sealed = try AES.GCM.seal(plaintext, using: key)
            guard let combined = sealed.combined else {
                throw VaultError.badEnvelope
            }
            return magic + combined
        } catch let error as VaultError {
            throw error
        } catch {
            throw VaultError.crypto(error)
        }
    }

    /// Decrypts a blob written by ``encrypt(_:)``. Does **not** create a new Keychain key.
    static func decrypt(_ wrapped: Data) throws -> Data {
        guard wrapped.count >= magic.count + 12 + 16 else {
            throw VaultError.badEnvelope
        }
        guard wrapped.prefix(magic.count) == magic else {
            throw VaultError.badEnvelope
        }
        let combined = wrapped.dropFirst(magic.count)
        guard let key = try loadKeyOnly() else {
            throw VaultError.keyMissing
        }
        do {
            let box = try AES.GCM.SealedBox(combined: Data(combined))
            return try AES.GCM.open(box, using: key)
        } catch {
            throw VaultError.crypto(error)
        }
    }

    // MARK: - Keychain

    private static func loadKeyOnly() throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw VaultError.keychain(status)
        }
        guard data.count == 32 else {
            throw VaultError.badEnvelope
        }
        return SymmetricKey(data: data)
    }

    private static func materialKey() throws -> SymmetricKey {
        if let existing = try loadKeyOnly() {
            return existing
        }
        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let status = SecItemAdd(add as CFDictionary, nil)
        if status == errSecDuplicateItem {
            guard let existing = try loadKeyOnly() else {
                throw VaultError.keychain(status)
            }
            return existing
        }
        guard status == errSecSuccess else {
            throw VaultError.keychain(status)
        }
        return key
    }
}
