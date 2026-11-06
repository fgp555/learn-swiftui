//
//  MyApp.swift
//  myapp
//
//  Created by m1 on 05/11/2026.
//

import SwiftUI

@main
struct MyApp: App {
    private enum SessionState {
        case restoring
        case signedOut
        case signedIn(AuthSession, UserProfile?)
        case restoreFailed(String)
        case clearFailed
    }

    @State private var state: SessionState = .restoring
    private let keychain = SessionKeychain()

    var body: some Scene {
        WindowGroup {
            Group {
                switch state {
                case .restoring:
                    ProgressView("Comprobando sesión…")
                case .signedOut:
                    LoginScreen(onLogin: signIn)
                case let .signedIn(session, profile):
                    MainTabView(session: session, initialProfile: profile, onLogout: clearSession)
                case let .restoreFailed(message):
                    VStack(spacing: 16) {
                        Text(message)
                        Button("Reintentar") {
                            Task { await restoreSession() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                case .clearFailed:
                    VStack(spacing: 16) {
                        Text("No se pudo borrar la sesión de Keychain.")
                        Button("Reintentar", action: clearSession)
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .task {
                if case .restoring = state {
                    await restoreSession()
                }
            }
        }
    }

    private func signIn(_ session: AuthSession) throws {
        try keychain.save(session)
        state = .signedIn(session, nil)
    }

    private func restoreSession() async {
        state = .restoring

        do {
            guard let session = try keychain.load() else {
                state = .signedOut
                return
            }
            let profile = try await AuthAPI().profile(token: session.token)
            try Task.checkCancellation()
            state = .signedIn(session, profile)
        } catch AuthAPI.RequestError.invalidSession {
            clearSession()
        } catch {
            guard !Task.isCancelled else { return }
            let message = (error as? SessionKeychain.Failure)?.localizedDescription
                ?? "No se pudo comprobar la sesión. Comprueba que el backend esté encendido."
            state = .restoreFailed(message)
        }
    }

    private func clearSession() {
        do {
            try keychain.remove()
            state = .signedOut
        } catch {
            state = .clearFailed
        }
    }
}
