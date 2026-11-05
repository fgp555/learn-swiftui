import SwiftUI

struct FormularioTexto: View {
    @State private var texto = ""
    let onSubmit: (String) -> Void

    private var textoLimpio: String {
        texto.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack {
            TextField("Escribe un mensaje", text: $texto)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit(enviar)

            Button("Enviar", action: enviar)
                .buttonStyle(.borderedProminent)
                .disabled(textoLimpio.isEmpty)
        }
    }

    private func enviar() {
        let mensaje = textoLimpio
        guard !mensaje.isEmpty else { return }
        onSubmit(mensaje)
        texto = ""
    }
}
