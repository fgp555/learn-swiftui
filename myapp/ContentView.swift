import SwiftUI

struct ContentView: View {
    @State private var puntos = 0
    @State private var mensajeEnviado: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Puntos: \(puntos)")
                .font(.largeTitle)

            Button("Sumar 1") {
                puntos += 1
            }

            Button("Escribir log") {
                print("[myapp] Puntos actuales: \(puntos)")
            }

            FormularioTexto { mensaje in
                mensajeEnviado = mensaje
            }

            if let mensajeEnviado {
                Text("Último mensaje: \(mensajeEnviado)")
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
