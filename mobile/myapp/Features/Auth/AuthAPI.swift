import Foundation

struct AuthSession: Decodable {
    let token: String
    let expiresAt: Date
}

struct UserProfile: Decodable {
    let id: Int
    let email: String
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
        switch status {
        case 200:
            return try JSONDecoder().decode(UserProfile.self, from: data)
        case 401:
            throw RequestError.invalidSession
        default:
            throw RequestError.invalidResponse
        }
    }

    func logout(token: String) async throws {
        let (_, status) = try await send(makeRequest("logout", method: "POST", token: token))
        switch status {
        case 204:
            return
        case 401:
            throw RequestError.invalidSession
        default:
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
