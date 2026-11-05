import SwiftUI

struct CounterDetailScreen: View {
    let points: Int

    var body: some View {
        Text("Tienes \(points) puntos")
            .font(.largeTitle)
            .navigationTitle("Detalle")
    }
}
