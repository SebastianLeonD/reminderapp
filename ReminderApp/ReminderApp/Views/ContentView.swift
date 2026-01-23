import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: ReminderStore
    @State private var selectedTab = 0
    @State private var showCreateSheet = false

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }
                .tag(0)

            AllRemindersView()
                .tabItem {
                    Label("All", systemImage: "list.bullet")
                }
                .tag(1)

            CreateReminderView()
                .tabItem {
                    Label("Create", systemImage: "plus.circle.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .task {
            await store.fetchReminders()
        }
        .alert("Error", isPresented: .constant(store.errorMessage != nil)) {
            Button("OK") {
                store.clearError()
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ReminderStore())
}
