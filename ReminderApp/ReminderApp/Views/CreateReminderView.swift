import SwiftUI
import Speech
import AVFoundation

struct CreateReminderView: View {
    @EnvironmentObject var store: ReminderStore
    @State private var inputText = ""
    @State private var isRecording = false
    @State private var isSending = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    // Speech Recognition
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var hasPermission = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)

                    Text("Create Reminder")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Type or speak your reminder naturally")
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)

                // Text Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("What do you need to remember?")
                        .font(.headline)

                    TextEditor(text: $inputText)
                        .frame(minHeight: 100, maxHeight: 150)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
                .padding(.horizontal)

                // Voice Button
                VStack(spacing: 12) {
                    Button {
                        if isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    } label: {
                        HStack {
                            Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.title2)
                            Text(isRecording ? "Stop Recording" : "Tap to Speak")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isRecording ? Color.red : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!hasPermission)

                    if isRecording {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("Listening...")
                                .foregroundColor(.secondary)
                        }
                    }

                    if !hasPermission {
                        Text("Microphone access required for voice input")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Examples
                VStack(alignment: .leading, spacing: 8) {
                    Text("Examples:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\"Remind me to call mom tomorrow at 5pm\"")
                        Text("\"Submit homework by Friday 3pm, high priority\"")
                        Text("\"Gym session Monday at 7am\"")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                // Send Button
                Button {
                    sendReminder()
                } label: {
                    HStack {
                        if isSending {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text(isSending ? "Sending..." : "Create Reminder")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(inputText.isEmpty ? Color.gray : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(inputText.isEmpty || isSending)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .onAppear {
                requestPermissions()
            }
            .alert("Success!", isPresented: $showSuccess) {
                Button("OK") {
                    inputText = ""
                    Task { await store.fetchReminders() }
                }
            } message: {
                Text("Your reminder has been created successfully.")
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Permissions
    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    AVAudioApplication.requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            hasPermission = granted
                        }
                    }
                default:
                    hasPermission = false
                }
            }
        }
    }

    // MARK: - Speech Recognition
    func startRecording() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition not available"
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let request = recognitionRequest else { return }

            request.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                request.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            isRecording = true

            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let result = result {
                    inputText = result.bestTranscription.formattedString
                }

                if error != nil || result?.isFinal == true {
                    stopRecording()
                }
            }
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }

    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }

    // MARK: - Send to Telegram Webhook
    func sendReminder() {
        guard !inputText.isEmpty else { return }

        isSending = true

        // This sends directly to your existing Telegram bot webhook
        // The n8n workflow will process it the same way as Telegram messages
        Task {
            do {
                // Use your existing Telegram bot webhook
                let webhookURL = "https://mac-mini.n8nworkflowssebox.uk/webhook/65e7a10e-27b7-4621-84ed-3d489ef5e2d4"

                guard let url = URL(string: webhookURL) else {
                    throw URLError(.badURL)
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                // Simulate Telegram message format that your workflow expects
                let payload: [String: Any] = [
                    "message": [
                        "text": inputText,
                        "from": [
                            "id": 0, // Your chat ID if needed
                            "is_bot": false,
                            "username": "ios_app"
                        ],
                        "chat": [
                            "id": 0 // Your chat ID
                        ],
                        "message_id": Int(Date().timeIntervalSince1970)
                    ],
                    "update_id": Int(Date().timeIntervalSince1970)
                ]

                request.httpBody = try JSONSerialization.data(withJSONObject: payload)

                let (_, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    await MainActor.run {
                        isSending = false
                        showSuccess = true
                    }
                } else {
                    throw URLError(.badServerResponse)
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    errorMessage = "Failed to create reminder: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    CreateReminderView()
        .environmentObject(ReminderStore())
}
