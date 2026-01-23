import SwiftUI

struct ReminderRowView: View {
    let reminder: Reminder

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

    var isOverdue: Bool {
        reminder.eventTime < Date() && !reminder.sent
    }

    var body: some View {
        HStack(spacing: 12) {
            // Priority indicator
            Circle()
                .fill(priorityColor)
                .frame(width: 10, height: 10)

            // Category icon
            Image(systemName: reminder.category.icon)
                .foregroundColor(categoryColor)
                .frame(width: 24)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(reminder.title)
                        .font(.headline)
                        .strikethrough(reminder.sent, color: .secondary)
                        .foregroundColor(reminder.sent ? .secondary : .primary)

                    if reminder.sent {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }

                HStack(spacing: 8) {
                    // Time
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(formatTime(reminder.eventTime))
                            .font(.caption)
                    }
                    .foregroundColor(isOverdue ? .red : .secondary)

                    // Category tag
                    Text(reminder.category.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(categoryColor.opacity(0.2))
                        .foregroundColor(categoryColor)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            // Overdue indicator
            if isOverdue {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
            return "Today, \(formatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "h:mm a"
            return "Tomorrow, \(formatter.string(from: date))"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: date)
        }
    }
}

#Preview {
    List {
        ReminderRowView(reminder: Reminder(
            id: "1",
            calendarEventId: "cal1",
            title: "Test Reminder",
            description: "This is a test",
            category: .homework,
            priority: .high,
            eventTime: Date(),
            sent: false,
            createdAt: Date(),
            reminderTimes: nil
        ))
        ReminderRowView(reminder: Reminder(
            id: "2",
            calendarEventId: "cal2",
            title: "Completed Task",
            description: "This is done",
            category: .work,
            priority: .medium,
            eventTime: Date(),
            sent: true,
            createdAt: Date(),
            reminderTimes: nil
        ))
    }
}
