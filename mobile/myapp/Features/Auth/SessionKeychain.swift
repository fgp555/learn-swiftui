import Foundation
import Security

struct SessionKeychain {
    struct Failure: LocalizedError {
        let status: OSStatus

        var errorDescription: String? {
            "No se pudo acceder a la sesión guardada en Keychain."
        }
    }

    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.frankgp.myapp",
            kSecAttrAccount as String: "auth-session"
        ]
    }

    func load() throws -> AuthSession? {
        var attributes = query
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(attributes as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw Failure(status: status == errSecSuccess ? errSecDecode : status)
        }

        do {
            return try JSONDecoder().decode(AuthSession.self, from: data)
        } catch is DecodingError {
            try remove()
            return nil
        }
    }

    func save(_ session: AuthSession) throws {
        let data = try JSONEncoder().encode(session)
        let values = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            var attributes = query
            attributes[kSecValueData as String] = data
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(attributes as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw Failure(status: status) }
    }

    func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Failure(status: status)
        }
    }
}
