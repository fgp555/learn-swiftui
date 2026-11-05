import SwiftUI

struct MainTabView: View {
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
        }
    }
}

#Preview {
    MainTabView()
}
