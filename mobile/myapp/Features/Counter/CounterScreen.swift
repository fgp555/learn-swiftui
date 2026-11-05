import SwiftUI

struct CounterScreen: View {
    @State private var points = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Puntos: \(points)")
                .font(.largeTitle)

            Button("Sumar 1") {
                points += 1
            }.buttonStyle(.borderedProminent)

            Button("Escribir log") {
                print("[myapp] Puntos actuales: \(points)")
            }

            NavigationLink("Ver detalle") {
                CounterDetailScreen(points: points)
            }
        }
        .padding()
        .navigationTitle("Counter")
    }
}
