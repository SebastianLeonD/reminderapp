import SwiftUI

struct AllRemindersView: View {
    @EnvironmentObject var store: ReminderStore
    @State private var searchText = ""

    var searchedReminders: [Reminder] {
        if searchText.isEmpty {
            return store.filteredReminders
        }
        return store.filteredReminders.filter { reminder in
            reminder.title.localizedCaseInsensitiveContains(searchText) ||
            reminder.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Filters
                Section {
                    // Category Filter
                    Menu {
                        Button("All Categories") {
                            store.selectedCategory = nil
                        }
                        ForEach(Reminder.Category.allCases, id: \.self) { category in
                            Button {
                                store.selectedCategory = category
                            } label: {
                                Label(category.displayName, systemImage: category.icon)
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "folder")
                            Text(store.selectedCategory?.displayName ?? "All Categories")
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Priority Filter
                    Menu {
                        Button("All Priorities") {
                            store.selectedPriority = nil
                        }
                        ForEach(Reminder.Priority.allCases, id: \.self) { priority in
                            Button(priority.displayName) {
                                store.selectedPriority = priority
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "flag")
                            Text(store.selectedPriority?.displayName ?? "All Priorities")
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Show Completed Toggle
                    Toggle(isOn: $store.showCompletedOnly) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("Completed Only")
                        }
                    }
                } header: {
                    Text("Filters")
                }

                // Reminders List
                Section {
                    if searchedReminders.isEmpty {
                        ContentUnavailableView(
                            "No Reminders",
                            systemImage: "tray",
                            description: Text("No reminders match your filters")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(searchedReminders) { reminder in
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
                                if !reminder.sent {
                                    Button {
                                        Task { await store.markComplete(reminder) }
                                    } label: {
                                        Label("Complete", systemImage: "checkmark")
                                    }
                                    .tint(.green)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Reminders (\(searchedReminders.count))")
                }
            }
            .navigationTitle("All Reminders")
            .searchable(text: $searchText, prompt: "Search reminders")
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
    AllRemindersView()
        .environmentObject(ReminderStore())
}
