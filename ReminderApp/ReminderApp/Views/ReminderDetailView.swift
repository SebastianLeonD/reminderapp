import SwiftUI

struct ReminderDetailView: View {
    @EnvironmentObject var store: ReminderStore
    @Environment(\.dismiss) var dismiss
    let reminder: Reminder

    @State private var isEditing = false
    @State private var editTitle: String = ""
    @State private var editDescription: String = ""
    @State private var editCategory: Reminder.Category = .personal
    @State private var editPriority: Reminder.Priority = .medium
    @State private var showDeleteConfirmation = false

    var priorityColor: Color {
        switch reminder.priority {
        case .high: return .red
        case .medium: return .yellow
        case .low: return .green
        }
    }

    var categoryColor: Color {
        switch reminder.category {
        case .homework: return .blue
        case .applications: return .purple
        case .gym: return .orange
        case .personal: return .green
        case .work: return .gray
        }
    }

    var body: some View {
        List {
            // Main Info Section
            Section {
                if isEditing {
                    TextField("Title", text: $editTitle)
                        .font(.headline)
                    TextField("Description", text: $editDescription, axis: .vertical)
                        .lineLimit(3...6)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(reminder.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .strikethrough(reminder.sent, color: .secondary)

                        Text(reminder.description)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Category & Priority Section
            Section {
                if isEditing {
                    Picker("Category", selection: $editCategory) {
                        ForEach(Reminder.Category.allCases, id: \.self) { category in
                            Label(category.displayName, systemImage: category.icon)
                                .tag(category)
                        }
                    }

                    Picker("Priority", selection: $editPriority) {
                        ForEach(Reminder.Priority.allCases, id: \.self) { priority in
                            Text(priority.displayName)
                                .tag(priority)
                        }
                    }
                } else {
                    HStack {
                        Label("Category", systemImage: reminder.category.icon)
                        Spacer()
                        Text(reminder.category.displayName)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(categoryColor.opacity(0.2))
                            .foregroundColor(categoryColor)
                            .clipShape(Capsule())
                    }

                    HStack {
                        Label("Priority", systemImage: "flag.fill")
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(priorityColor)
                                .frame(width: 10, height: 10)
                            Text(reminder.priority.displayName)
                        }
                    }
                }
            } header: {
                Text("Details")
            }

            // Time Section
            Section {
                HStack {
                    Label("Event Time", systemImage: "calendar")
                    Spacer()
                    Text(formatDate(reminder.eventTime))
                        .foregroundColor(.secondary)
                }

                if reminder.sent {
                    HStack {
                        Label("Status", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Spacer()
                        Text("Completed")
                            .foregroundColor(.green)
                    }
                } else {
                    HStack {
                        Label("Status", systemImage: "clock")
                        Spacer()
                        Text(isOverdue ? "Overdue" : "Pending")
                            .foregroundColor(isOverdue ? .red : .orange)
                    }
                }

                HStack {
                    Label("Created", systemImage: "plus.circle")
                    Spacer()
                    Text(formatDate(reminder.createdAt))
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Schedule")
            }

            // Actions Section
            if !isEditing {
                Section {
                    if !reminder.sent {
                        Button {
                            Task {
                                await store.markComplete(reminder)
                                dismiss()
                            }
                        } label: {
                            Label("Mark as Completed", systemImage: "checkmark.circle")
                                .foregroundColor(.green)
                        }
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Reminder", systemImage: "trash")
                    }
                } header: {
                    Text("Actions")
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Reminder" : "Reminder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("Save") {
                        Task {
                            await store.updateReminder(
                                reminder,
                                title: editTitle,
                                description: editDescription,
                                category: editCategory,
                                priority: editPriority
                            )
                            isEditing = false
                            dismiss()
                        }
                    }
                } else {
                    Button("Edit") {
                        editTitle = reminder.title
                        editDescription = reminder.description
                        editCategory = reminder.category
                        editPriority = reminder.priority
                        isEditing = true
                    }
                }
            }

            if isEditing {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isEditing = false
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete Reminder",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    await store.deleteReminder(reminder)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this reminder? This action cannot be undone.")
        }
    }

    var isOverdue: Bool {
        reminder.eventTime < Date() && !reminder.sent
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        ReminderDetailView(reminder: Reminder(
            id: "1",
            calendarEventId: "cal1",
            title: "Test Reminder",
            description: "This is a test reminder with some description text",
            category: .homework,
            priority: .high,
            eventTime: Date(),
            sent: false,
            createdAt: Date(),
            reminderTimes: nil
        ))
        .environmentObject(ReminderStore())
    }
}
