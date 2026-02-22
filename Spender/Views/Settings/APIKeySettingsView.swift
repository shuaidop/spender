import SwiftUI

struct APIKeySettingsView: View {
    @State private var apiKey: String = ""
    @State private var isKeySet: Bool = false
    @State private var showKey: Bool = false
    @State private var statusMessage: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("OpenAI API Key")
                .font(.title2.bold())

            Text("Required for transaction classification and chat analysis.")
                .foregroundStyle(.secondary)

            HStack {
                if showKey {
                    TextField("sk-...", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("sk-...", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                }

                Button {
                    showKey.toggle()
                } label: {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain)
            }

            HStack {
                Button("Save Key") {
                    KeychainHelper.save(key: "openai_api_key", value: apiKey)
                    isKeySet = true
                    statusMessage = "API key saved securely."
                }
                .disabled(apiKey.isEmpty)

                if isKeySet {
                    Button("Remove Key", role: .destructive) {
                        KeychainHelper.delete(key: "openai_api_key")
                        apiKey = ""
                        isKeySet = false
                        statusMessage = "API key removed."
                    }
                }

                Spacer()

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isKeySet {
                Label("API key is configured", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Label("No API key configured", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            if let existing = KeychainHelper.retrieve(key: "openai_api_key") {
                apiKey = existing
                isKeySet = true
            }
        }
    }
}
