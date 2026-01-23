import Foundation
import SwiftUI

@MainActor
class ReminderStore: ObservableObject {
    @Published var reminders: [Reminder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedCategory: Reminder.Category?
    @Published var selectedPriority: Reminder.Priority?
    @Published var showCompletedOnly = false
    @Published var showUpcomingOnly = true

    private let apiService = APIService()

    var filteredReminders: [Reminder] {
        reminders.filter { reminder in
            if let category = selectedCategory, reminder.category != category {
                return false
            }
            if let priority = selectedPriority, reminder.priority != priority {
                return false
            }
            if showCompletedOnly && !reminder.sent {
                return false
            }
            if showUpcomingOnly && reminder.sent {
                return false
            }
            return true
        }
    }

    var todaysReminders: [Reminder] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        return filteredReminders.filter { reminder in
            reminder.eventTime >= today && reminder.eventTime < tomorrow
        }
    }

    var upcomingReminders: [Reminder] {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!

        return filteredReminders.filter { reminder in
            reminder.eventTime >= tomorrow
        }
    }

    var overdueReminders: [Reminder] {
        let now = Date()
        return filteredReminders.filter { reminder in
            reminder.eventTime < now && !reminder.sent
        }
    }

    // MARK: - Fetch
    func fetchReminders() async {
        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await apiService.fetchReminders()
            self.reminders = fetched.sorted { $0.eventTime < $1.eventTime }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Update
    func updateReminder(
        _ reminder: Reminder,
        title: String? = nil,
        description: String? = nil,
        category: Reminder.Category? = nil,
        priority: Reminder.Priority? = nil
    ) async {
        do {
            try await apiService.updateReminder(
                id: reminder.id,
                title: title,
                description: description,
                category: category,
                priority: priority
            )
            await fetchReminders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete
    func deleteReminder(_ reminder: Reminder) async {
        do {
            try await apiService.deleteReminder(id: reminder.id)
            self.reminders.removeAll { $0.id == reminder.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Mark Complete
    func markComplete(_ reminder: Reminder) async {
        do {
            try await apiService.markComplete(id: reminder.id)
            if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
                reminders[index].sent = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Clear Error
    func clearError() {
        errorMessage = nil
    }
}
