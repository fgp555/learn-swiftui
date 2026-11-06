import SwiftUI

struct ProfileScreen: View {
    let session: AuthSession
    let profile: UserProfile?
    let avatar: UIImage?
    let isLoadingProfile: Bool
    let profileError: String?
    let onRetry: () async -> Void
    let onSave: (UserProfile) -> Void
    let onLogout: () -> Void

    @State private var isEditing = false
    @State private var isLoggingOut = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Cuenta") {
                if let profile {
                    VStack(spacing: 8) {
                        ProfileAvatar(initials: profile.initials, image: avatar)

                        Text(profile.displayName.isEmpty ? "Sin nombre" : profile.displayName)
                            .font(.title2.bold())
                        Text(profile.email)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Button("Editar perfil") { isEditing = true }
                        .disabled(isLoggingOut)
                } else if isLoadingProfile {
                    ProgressView("Cargando perfil…")
                } else {
                    Button("Reintentar") {
                        Task { await onRetry() }
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

                if let errorMessage = errorMessage ?? profileError {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Profile")
        .sheet(isPresented: $isEditing) {
            if let profile {
                EditProfileScreen(
                    profile: profile,
                    currentAvatar: avatar,
                    token: session.token,
                    onSave: onSave,
                    onExpired: onLogout
                )
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
