import Foundation

struct Reminder: Identifiable, Codable, Equatable {
    let id: String
    let calendarEventId: String?
    var title: String
    var description: String
    var category: Category
    var priority: Priority
    var eventTime: Date
    var sent: Bool
    let createdAt: Date
    var reminderTimes: [ReminderTime]?

    enum Category: String, Codable, CaseIterable {
        case homework = "homework"
        case applications = "applications"
        case gym = "gym"
        case personal = "personal"
        case work = "work"

        var displayName: String {
            rawValue.capitalized
        }

        var icon: String {
            switch self {
            case .homework: return "book.fill"
            case .applications: return "doc.text.fill"
            case .gym: return "dumbbell.fill"
            case .personal: return "person.fill"
            case .work: return "briefcase.fill"
            }
        }

        var color: String {
            switch self {
            case .homework: return "blue"
            case .applications: return "purple"
            case .gym: return "orange"
            case .personal: return "green"
            case .work: return "gray"
            }
        }
    }

    enum Priority: String, Codable, CaseIterable {
        case high = "high"
        case medium = "medium"
        case low = "low"

        var displayName: String {
            rawValue.capitalized
        }

        var color: String {
            switch self {
            case .high: return "red"
            case .medium: return "yellow"
            case .low: return "green"
            }
        }
    }

    struct ReminderTime: Codable, Equatable {
        let reminderId: String
        let reminderTime: Date
        let offsetMinutes: Int
    }
}

struct RemindersResponse: Codable {
    let success: Bool
    let count: Int?
    let reminders: [APIReminder]?
    let error: String?
}

struct SingleReminderResponse: Codable {
    let success: Bool
    let reminder: APIReminder?
    let error: String?
}

struct APIReminder: Codable {
    let id: String
    let calendarEventId: String?
    let title: String
    let description: String
    let category: String
    let priority: String
    let eventTime: String
    let sent: Bool
    let createdAt: String
    let reminderTimes: [APIReminderTime]?

    struct APIReminderTime: Codable {
        let reminderId: String
        let reminderTime: String
        let offsetMinutes: Int
    }
}

extension Reminder {
    static func from(apiReminder: APIReminder) -> Reminder {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy HH:mm"
        dateFormatter.timeZone = TimeZone(identifier: "America/New_York")

        let eventDate = dateFormatter.date(from: apiReminder.eventTime) ?? Date()
        let createdDate = dateFormatter.date(from: apiReminder.createdAt) ?? Date()

        let reminderTimes = apiReminder.reminderTimes?.map { apiTime -> ReminderTime in
            let time = dateFormatter.date(from: apiTime.reminderTime) ?? Date()
            return ReminderTime(
                reminderId: apiTime.reminderId,
                reminderTime: time,
                offsetMinutes: apiTime.offsetMinutes
            )
        }

        return Reminder(
            id: apiReminder.id,
            calendarEventId: apiReminder.calendarEventId,
            title: apiReminder.title,
            description: apiReminder.description,
            category: Category(rawValue: apiReminder.category) ?? .personal,
            priority: Priority(rawValue: apiReminder.priority) ?? .medium,
            eventTime: eventDate,
            sent: apiReminder.sent,
            createdAt: createdDate,
            reminderTimes: reminderTimes
        )
    }
}
