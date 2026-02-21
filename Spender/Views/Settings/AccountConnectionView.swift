import SwiftUI

struct AccountConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isConnecting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text("Connect Your Bank")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Securely link your Amex or Chase credit card to automatically import transactions.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "lock.fill", text: "Bank-level encryption via Plaid")
                    FeatureRow(icon: "eye.slash.fill", text: "We never see your credentials")
                    FeatureRow(icon: "iphone", text: "Data stays on your device")
                }
                .padding(.horizontal, 32)
                .padding(.vertical)

                Button {
                    isConnecting = true
                    // Plaid Link will be connected in Phase 2
                } label: {
                    Text("Connect Account")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 32)
                .disabled(isConnecting)

                if isConnecting {
                    ProgressView("Preparing secure connection...")
                }

                Spacer()
            }
            .padding(.top, 40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}
