import SwiftUI

@main
struct ReminderAppApp: App {
    @StateObject private var reminderStore = ReminderStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(reminderStore)
        }
    }
}
