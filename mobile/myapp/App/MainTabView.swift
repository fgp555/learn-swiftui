import SwiftUI

struct MainTabView: View {
    let session: AuthSession
    let onLogout: () -> Void

    @State private var profile: UserProfile?
    @State private var isLoadingProfile = true
    @State private var profileError: String?
    @State private var avatar: UIImage?
    @State private var avatarRevision = 0

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                NavigationStack {
                    HomeScreen()
                }
            }

            Tab("Form", systemImage: "square.and.pencil") {
                NavigationStack {
                    FormScreen()
                }
            }

            Tab("Counter", systemImage: "number") {
                NavigationStack {
                    CounterScreen()
                }
            }

            Tab {
                NavigationStack {
                    ProfileScreen(
                        session: session,
                        profile: profile,
                        avatar: avatar,
                        isLoadingProfile: isLoadingProfile,
                        profileError: profileError,
                        onRetry: loadProfile,
                        onSave: applyProfile,
                        onLogout: onLogout
                    )
                }
            } label: {
                Label {
                    Text("Profile")
                } icon: {
                    profileTabIcon
                }
            }
        }
        .task {
            if profile == nil {
                await loadProfile()
            }
        }
        .task(id: avatarRevision) {
            guard let profile else { return }
            let image = await ProfileAvatar.loadImage(for: profile, token: session.token)
            if !Task.isCancelled {
                avatar = image
            }
        }
    }

    private var profileTabIcon: Image {
        guard let avatar else {
            return Image(systemName: "person.crop.circle")
        }

        let size = CGSize(width: 25, height: 25)
        let bounds = CGRect(origin: .zero, size: size)
        let icon = UIGraphicsImageRenderer(size: size).image { _ in
            UIBezierPath(ovalIn: bounds).addClip()
            let scale = max(size.width / avatar.size.width, size.height / avatar.size.height)
            let width = avatar.size.width * scale
            let height = avatar.size.height * scale
            avatar.draw(in: CGRect(
                x: (size.width - width) / 2,
                y: (size.height - height) / 2,
                width: width,
                height: height
            ))
        }
        return Image(uiImage: icon.withRenderingMode(.alwaysOriginal))
            .renderingMode(.original)
    }

    private func applyProfile(_ updated: UserProfile) {
        profile = updated
        avatar = nil
        avatarRevision += 1
    }

    private func loadProfile() async {
        isLoadingProfile = true
        profileError = nil
        defer { isLoadingProfile = false }

        do {
            let updated = try await AuthAPI().profile(token: session.token)
            try Task.checkCancellation()
            applyProfile(updated)
        } catch AuthAPI.RequestError.invalidSession {
            onLogout()
        } catch {
            if !Task.isCancelled {
                profileError = "No se pudo cargar el perfil. Inténtalo de nuevo."
            }
        }
    }
}

#Preview {
    MainTabView(session: AuthSession(token: "preview", expiresAt: .distantFuture)) {}
}
