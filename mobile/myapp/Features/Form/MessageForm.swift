import SwiftUI

struct MessageForm: View {
    @State private var text = ""
    let onSubmit: (String) -> Void

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack {
            TextField("Escribe un mensaje", text: $text)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit(submit)

            Button("Enviar", action: submit)
                .buttonStyle(.borderedProminent)
                .disabled(trimmedText.isEmpty)
        }
    }

    private func submit() {
        let message = trimmedText
        guard !message.isEmpty else { return }
        onSubmit(message)
        text = ""
    }
}
