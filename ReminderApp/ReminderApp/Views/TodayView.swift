import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: ReminderStore

    var body: some View {
        NavigationStack {
            List {
                // Overdue Section
                if !store.overdueReminders.isEmpty {
                    Section {
                        ForEach(store.overdueReminders) { reminder in
                            NavigationLink(destination: ReminderDetailView(reminder: reminder)) {
                                ReminderRowView(reminder: reminder)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await store.deleteReminder(reminder) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    Task { await store.markComplete(reminder) }
                                } label: {
                                    Label("Complete", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                        }
                    } header: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Overdue")
                                .foregroundColor(.red)
                        }
                    }
                }

                // Today Section
                Section {
                    if store.todaysReminders.isEmpty && store.overdueReminders.isEmpty {
                        ContentUnavailableView(
                            "No Reminders Today",
                            systemImage: "checkmark.circle",
                            description: Text("You're all caught up!")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(store.todaysReminders) { reminder in
                            NavigationLink(destination: ReminderDetailView(reminder: reminder)) {
                                ReminderRowView(reminder: reminder)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await store.deleteReminder(reminder) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    Task { await store.markComplete(reminder) }
                                } label: {
                                    Label("Complete", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .foregroundColor(.orange)
                        Text("Today")
                    }
                }
            }
            .navigationTitle("Today")
            .refreshable {
                await store.fetchReminders()
            }
            .overlay {
                if store.isLoading && store.reminders.isEmpty {
                    ProgressView("Loading...")
                }
            }
        }
    }
}

#Preview {
    TodayView()
        .environmentObject(ReminderStore())
}
