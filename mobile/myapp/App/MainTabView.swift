import SwiftUI

struct MainTabView: View {
    let session: AuthSession
    let onLogout: () -> Void

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

            Tab("Profile", systemImage: "person.crop.circle") {
                NavigationStack {
                    ProfileScreen(session: session, onLogout: onLogout)
                }
            }
        }
    }
}

#Preview {
    MainTabView(session: AuthSession(token: "preview", expiresAt: .distantFuture)) {}
}
