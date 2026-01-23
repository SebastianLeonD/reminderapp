import SwiftUI

struct SettingsView: View {
    @AppStorage("apiKey") private var apiKey = ""
    @AppStorage("baseURL") private var baseURL = "https://mac-mini.n8nworkflowssebox.uk"
    @State private var showAPIKey = false

    var body: some View {
        NavigationStack {
            List {
                // API Configuration
                Section {
                    HStack {
                        Text("Base URL")
                        Spacer()
                        TextField("URL", text: $baseURL)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("API Key")
                        Spacer()
                        if showAPIKey {
                            TextField("Key", text: $apiKey)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(.secondary)
                        } else {
                            Text(String(repeating: "*", count: min(apiKey.count, 20)))
                                .foregroundColor(.secondary)
                        }
                        Button {
                            showAPIKey.toggle()
                        } label: {
                            Image(systemName: showAPIKey ? "eye.slash" : "eye")
                        }
                    }
                } header: {
                    Text("API Configuration")
                } footer: {
                    Text("Configure your n8n webhook URL and API key for secure access.")
                }

                // About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Built with")
                        Spacer()
                        Text("SwiftUI + n8n")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }

                // Info
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(icon: "bell.fill", title: "Reminders", description: "Create and manage reminders via Telegram or this app")
                        InfoRow(icon: "mic.fill", title: "Voice Input", description: "Speak naturally to create reminders")
                        InfoRow(icon: "arrow.triangle.2.circlepath", title: "Sync", description: "Pull to refresh to sync with n8n")
                        InfoRow(icon: "hand.tap.fill", title: "Quick Actions", description: "Swipe left to delete, right to complete")
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("How to Use")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    SettingsView()
}
