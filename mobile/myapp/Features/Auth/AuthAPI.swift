import Foundation

struct AuthSession: Codable {
    let token: String
    let expiresAt: Date
}

struct UserProfile: Decodable {
    let id: Int
    let email: String
    let displayName: String
    let avatarURL: URL?
    let hasUploadedAvatar: Bool

    enum CodingKeys: String, CodingKey {
        case id, email
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case hasUploadedAvatar = "has_uploaded_avatar"
    }

    var initials: String {
        let words = displayName.split(whereSeparator: \.isWhitespace)
        let letters = words.prefix(2).compactMap(\.first)
        return letters.isEmpty ? String(email.prefix(1)).uppercased() : String(letters).uppercased()
    }
}

struct AuthAPI {
    private let baseURL = URL(string: "http://localhost:8080/v1/auth/")!

    enum RequestError: LocalizedError {
        case invalidCredentials
        case invalidSession
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .invalidCredentials:
                "El correo o la contraseña son incorrectos."
            case .invalidSession:
                "La sesión ya no está activa."
            case .invalidResponse:
                "El servidor no pudo completar la solicitud. Inténtalo de nuevo."
            }
        }
    }

    private struct Credentials: Encodable {
        let email: String
        let password: String
    }

    func login(email: String, password: String) async throws -> AuthSession {
        var request = makeRequest("login", method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Credentials(email: email, password: password))

        let (data, status) = try await send(request)
        switch status {
        case 200:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(AuthSession.self, from: data)
        case 401:
            throw RequestError.invalidCredentials
        default:
            throw RequestError.invalidResponse
        }
    }

    func profile(token: String) async throws -> UserProfile {
        let (data, status) = try await send(makeRequest("me", method: "GET", token: token))
        try requireSuccess(status, expected: 200)
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }

    func updateProfile(name: String, avatar: Data?, removeAvatar: Bool, token: String) async throws -> UserProfile {
        struct Update: Encodable {
            let displayName: String
            let avatarJPEG: Data?
            let removeAvatar: Bool

            enum CodingKeys: String, CodingKey {
                case displayName = "display_name"
                case avatarJPEG = "avatar_jpeg"
                case removeAvatar = "remove_avatar"
            }
        }

        var request = makeRequest("me", method: "PATCH", token: token)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Update(displayName: name, avatarJPEG: avatar, removeAvatar: removeAvatar))
        let (data, status) = try await send(request)
        try requireSuccess(status, expected: 200)
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }

    func avatar(token: String) async throws -> Data {
        let url = baseURL.appending(path: "me").appending(path: "avatar")
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, status) = try await send(request)
        try requireSuccess(status, expected: 200)
        return data
    }

    func logout(token: String) async throws {
        let (_, status) = try await send(makeRequest("logout", method: "POST", token: token))
        try requireSuccess(status, expected: 204)
    }

    private func requireSuccess(_ status: Int, expected: Int) throws {
        if status == 401 {
            throw RequestError.invalidSession
        }
        guard status == expected else {
            throw RequestError.invalidResponse
        }
    }

    private func makeRequest(_ endpoint: String, method: String, token: String? = nil) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: endpoint), timeoutInterval: 10)
        request.httpMethod = method
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw RequestError.invalidResponse
        }
        return (data, response.statusCode)
    }
}
