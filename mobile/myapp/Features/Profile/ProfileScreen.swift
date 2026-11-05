import SwiftUI

struct ProfileScreen: View {
    let session: AuthSession
    let onLogout: () -> Void

    @State private var email: String?
    @State private var isLoadingProfile = true
    @State private var isLoggingOut = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Cuenta") {
                if let email {
                    LabeledContent("Correo electrónico", value: email)
                } else if isLoadingProfile {
                    ProgressView("Cargando perfil…")
                } else {
                    Button("Reintentar") {
                        Task { await loadProfile() }
                    }
                    .disabled(isLoggingOut)
                }
            }

            Section {
                Button("Cerrar sesión", role: .destructive, action: logout)
                    .disabled(isLoggingOut || isLoadingProfile)

                if isLoggingOut {
                    ProgressView("Cerrando sesión…")
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Profile")
        .task {
            if email == nil {
                await loadProfile()
            }
        }
    }

    private func loadProfile() async {
        isLoadingProfile = true
        errorMessage = nil
        defer { isLoadingProfile = false }

        do {
            email = try await AuthAPI().profile(token: session.token).email
        } catch AuthAPI.RequestError.invalidSession {
            onLogout()
        } catch {
            if !Task.isCancelled {
                errorMessage = "No se pudo cargar el perfil. Inténtalo de nuevo."
            }
        }
    }

    private func logout() {
        guard !isLoggingOut else { return }
        isLoggingOut = true
        errorMessage = nil

        Task {
            defer { isLoggingOut = false }
            do {
                try await AuthAPI().logout(token: session.token)
                onLogout()
            } catch AuthAPI.RequestError.invalidSession {
                onLogout()
            } catch {
                errorMessage = "No se pudo cerrar la sesión. Inténtalo de nuevo."
            }
        }
    }
}
