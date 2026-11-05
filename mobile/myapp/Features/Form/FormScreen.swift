import SwiftUI

struct FormScreen: View {
    @State private var submittedMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            MessageForm { message in
                submittedMessage = message
            }

            if let submittedMessage {
                Text("Último mensaje: \(submittedMessage)")
            }
        }
        .padding()
        .navigationTitle("Form")
    }
}
