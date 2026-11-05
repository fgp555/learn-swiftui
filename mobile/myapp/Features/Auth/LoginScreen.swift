import SwiftUI

struct LoginScreen: View {
    let onLogin: (AuthSession) -> Void

    @State private var email = "demo@example.com"
    @State private var password = "demo"
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !isSubmitting && !trimmedEmail.isEmpty && password.count >= 4
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Credenciales") {
                    TextField("Correo electrónico", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Contraseña", text: $password)
                        .textContentType(.password)
                        .submitLabel(.go)
                        .onSubmit(submit)
                }
                .disabled(isSubmitting)

                Section {
                    Button(action: submit) {
                        if isSubmitting {
                            ProgressView("Iniciando sesión…")
                        } else {
                            Text("Entrar")
                        }
                    }
                    .disabled(!canSubmit)

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Iniciar sesión")
        }
    }

    private func submit() {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil

        Task {
            defer { isSubmitting = false }
            do {
                let session = try await AuthAPI().login(email: trimmedEmail, password: password)
                onLogin(session)
            } catch let error as AuthAPI.RequestError {
                errorMessage = error.localizedDescription
            } catch is URLError {
                errorMessage = "No se pudo conectar. Comprueba que el backend esté encendido."
            } catch {
                errorMessage = "No se pudo iniciar sesión. Inténtalo de nuevo."
            }
        }
    }
}

#Preview {
    LoginScreen { _ in }
}
