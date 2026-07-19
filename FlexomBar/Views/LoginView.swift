import SwiftUI

/// Username/password form for the Flexom account.
struct LoginView: View {
    @Environment(FlexomStore.self) private var store

    @State private var username = ""
    @State private var password = ""

    private var isConnecting: Bool {
        store.status == .connecting
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "house.fill")
                Text("Compte Flexom")
                    .font(.headline)
            }

            TextField("E-mail", text: $username)
                .textContentType(.username)
                .disableAutocorrection(true)

            SecureField("Mot de passe", text: $password)
                .textContentType(.password)
                .onSubmit(submit)

            HStack {
                if isConnecting {
                    ProgressView()
                        .controlSize(.small)
                    Text("Connexion…")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Se connecter", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(username.isEmpty || password.isEmpty || isConnecting)
            }

            Divider()

            Button("Quitter FlexomBar") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.caption)
        }
        .padding()
        .textFieldStyle(.roundedBorder)
        .onAppear {
            username = store.savedUsername ?? ""
        }
    }

    private func submit() {
        guard !username.isEmpty, !password.isEmpty else { return }
        Task {
            await store.login(username: username, password: password)
        }
    }
}
