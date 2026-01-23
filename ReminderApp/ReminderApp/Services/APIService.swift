import Foundation

actor APIService {
    // MARK: - Configuration
    // TODO: Update these with your actual values
    static let baseURL = "https://mac-mini.n8nworkflowssebox.uk/webhook/api/reminders"
    static let apiKey = "YOUR_SECRET_API_KEY_HERE" // Match this with your n8n workflow

    enum APIError: LocalizedError {
        case invalidURL
        case networkError(Error)
        case decodingError(Error)
        case serverError(String)
        case unauthorized

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .decodingError(let error):
                return "Failed to decode response: \(error.localizedDescription)"
            case .serverError(let message):
                return message
            case .unauthorized:
                return "Unauthorized. Check your API key."
            }
        }
    }

    // MARK: - Fetch All Reminders
    func fetchReminders(
        category: Reminder.Category? = nil,
        priority: Reminder.Priority? = nil,
        date: String? = nil,
        upcoming: Bool = false,
        completed: Bool? = nil
    ) async throws -> [Reminder] {
        var components = URLComponents(string: Self.baseURL)

        var queryItems: [URLQueryItem] = []
        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category.rawValue))
        }
        if let priority = priority {
            queryItems.append(URLQueryItem(name: "priority", value: priority.rawValue))
        }
        if let date = date {
            queryItems.append(URLQueryItem(name: "date", value: date))
        }
        if upcoming {
            queryItems.append(URLQueryItem(name: "upcoming", value: "true"))
        }
        if let completed = completed {
            queryItems.append(URLQueryItem(name: "completed", value: completed ? "true" : "false"))
        }

        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(Self.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    throw APIError.unauthorized
                }
            }

            let decoded = try JSONDecoder().decode(RemindersResponse.self, from: data)

            if !decoded.success {
                throw APIError.serverError(decoded.error ?? "Unknown error")
            }

            return decoded.reminders?.map { Reminder.from(apiReminder: $0) } ?? []
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Get Single Reminder
    func getReminder(id: String) async throws -> Reminder {
        guard let url = URL(string: "\(Self.baseURL)/\(id)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(Self.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    throw APIError.unauthorized
                }
            }

            let decoded = try JSONDecoder().decode(SingleReminderResponse.self, from: data)

            if !decoded.success {
                throw APIError.serverError(decoded.error ?? "Reminder not found")
            }

            guard let apiReminder = decoded.reminder else {
                throw APIError.serverError("Reminder not found")
            }

            return Reminder.from(apiReminder: apiReminder)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Update Reminder
    func updateReminder(
        id: String,
        title: String? = nil,
        description: String? = nil,
        category: Reminder.Category? = nil,
        priority: Reminder.Priority? = nil,
        eventTime: Date? = nil
    ) async throws {
        guard let url = URL(string: "\(Self.baseURL)/\(id)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(Self.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [:]
        if let title = title { body["title"] = title }
        if let description = description { body["description"] = description }
        if let category = category { body["category"] = category.rawValue }
        if let priority = priority { body["priority"] = priority.rawValue }
        if let eventTime = eventTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yyyy HH:mm"
            formatter.timeZone = TimeZone(identifier: "America/New_York")
            body["eventTime"] = formatter.string(from: eventTime)
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    throw APIError.unauthorized
                }
            }

            struct UpdateResponse: Codable {
                let success: Bool
                let message: String?
                let error: String?
            }

            let decoded = try JSONDecoder().decode(UpdateResponse.self, from: data)

            if !decoded.success {
                throw APIError.serverError(decoded.error ?? "Update failed")
            }
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Delete Reminder
    func deleteReminder(id: String) async throws {
        guard let url = URL(string: "\(Self.baseURL)/\(id)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(Self.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    throw APIError.unauthorized
                }
            }

            struct DeleteResponse: Codable {
                let success: Bool
                let message: String?
                let error: String?
            }

            let decoded = try JSONDecoder().decode(DeleteResponse.self, from: data)

            if !decoded.success {
                throw APIError.serverError(decoded.error ?? "Delete failed")
            }
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Mark Complete
    func markComplete(id: String) async throws {
        guard let url = URL(string: "\(Self.baseURL)/\(id)/complete") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Self.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    throw APIError.unauthorized
                }
            }

            struct CompleteResponse: Codable {
                let success: Bool
                let message: String?
                let error: String?
            }

            let decoded = try JSONDecoder().decode(CompleteResponse.self, from: data)

            if !decoded.success {
                throw APIError.serverError(decoded.error ?? "Mark complete failed")
            }
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }
}
