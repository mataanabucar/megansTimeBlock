import AVFoundation
import Foundation
import Observation

struct QuickCaptureChip: Identifiable, Hashable {
    let id: String
    let title: String
    let category: TaskCategory?
    let minutes: Int?
    let dueDateOffset: Int?
    let flexibleWindow: String?

    init(
        title: String,
        category: TaskCategory? = nil,
        minutes: Int? = nil,
        dueDateOffset: Int? = nil,
        flexibleWindow: String? = nil
    ) {
        self.id = title
        self.title = title
        self.category = category
        self.minutes = minutes
        self.dueDateOffset = dueDateOffset
        self.flexibleWindow = flexibleWindow
    }

    static let defaults: [QuickCaptureChip] = [
        QuickCaptureChip(title: "Today", dueDateOffset: 0, flexibleWindow: "Today"),
        QuickCaptureChip(title: "Tomorrow", dueDateOffset: 1, flexibleWindow: "Tomorrow"),
        QuickCaptureChip(title: "This Week", dueDateOffset: 6, flexibleWindow: "This week"),
        QuickCaptureChip(title: "Home", category: .home),
        QuickCaptureChip(title: "Errand", category: .errand),
        QuickCaptureChip(title: "Family", category: .family),
        QuickCaptureChip(title: "Money", category: .money),
        QuickCaptureChip(title: "Appointment", category: .appointment),
        QuickCaptureChip(title: "Cleaning", category: .cleaning),
        QuickCaptureChip(title: "5 min", minutes: 5),
        QuickCaptureChip(title: "15 min", minutes: 15),
        QuickCaptureChip(title: "30 min", minutes: 30),
        QuickCaptureChip(title: "1 hour", minutes: 60)
    ]
}

@MainActor
@Observable
final class QuickCaptureViewModel {
    var rawText = ""
    var selectedChips: Set<QuickCaptureChip> = []
    var source: CaptureSource = .typed
    var voiceMessage: String?
    var isListening = false
    var voiceAutoSaveRequestID: UUID?

    @ObservationIgnored private let voiceRecorder = VoiceDumpRecorder()
    @ObservationIgnored private let voiceDumpService = VoiceDumpAPIService()
    @ObservationIgnored private var textBeforeVoiceCapture = ""
    @ObservationIgnored private var parsedVoiceTasks: [ParsedVoiceTask] = []
    @ObservationIgnored private var needsReview: [String] = []

    var canSave: Bool {
        !rawText.trimmedForStorage.isEmpty || !parsedVoiceTasks.isEmpty
    }

    var voiceButtonTitle: String {
        isListening ? "Stop and parse" : "Tap to speak"
    }

    var voiceButtonSystemImage: String {
        isListening ? "stop.circle.fill" : "mic.fill"
    }

    var saveButtonTitle: String {
        let count = pendingTaskCount
        return count > 1 ? "Save \(count) to Inbox" : "Save to Inbox"
    }

    private var pendingTaskCount: Int {
        if !parsedVoiceTasks.isEmpty {
            return parsedVoiceTasks.count
        }
        return Self.captureItems(from: rawText).count
    }

    func toggle(_ chip: QuickCaptureChip) {
        if selectedChips.contains(chip) {
            selectedChips.remove(chip)
        } else {
            selectedChips.insert(chip)
        }
    }

    func toggleVoiceCapture() async {
        if isListening {
            await stopVoiceCaptureAndParse(autosaves: true)
        } else {
            await startVoiceCapture()
        }
    }

    func makeTasks() -> [TaskItem] {
        let selectedCategory = selectedChips.compactMap(\.category).first
        let selectedMinutes = selectedChips.compactMap(\.minutes).first
        let dueDate = selectedChips.compactMap(\.dueDateOffset).min().flatMap { offset in
            Calendar.current.date(byAdding: .day, value: offset, to: Date())
        }
        let flexibleWindow = selectedChips.compactMap(\.flexibleWindow).first

        if !parsedVoiceTasks.isEmpty {
            return parsedVoiceTasks.map { parsedTask in
                let taskText = parsedTask.title.trimmedForStorage
                return TaskItem(
                    rawText: taskText,
                    category: selectedCategory ?? parsedTask.category,
                    priority: dueDate.map { Calendar.current.isDateInToday($0) ? .important : .normal } ?? .normal,
                    energyLevel: .any,
                    estimatedMinutes: selectedMinutes ?? parsedTask.estimatedMinutes,
                    dueDate: dueDate,
                    flexibleWindow: flexibleWindow,
                    source: .voice
                )
            }
        }

        let taskTexts = Self.captureItems(from: rawText)
        guard !taskTexts.isEmpty else { return [] }

        return taskTexts.map { taskText in
            TaskItem(
                rawText: taskText,
                category: selectedCategory ?? inferredCategory(from: taskText),
                priority: dueDate.map { Calendar.current.isDateInToday($0) ? .important : .normal } ?? .normal,
                energyLevel: .any,
                estimatedMinutes: selectedMinutes ?? inferredMinutes(from: taskText),
                dueDate: dueDate,
                flexibleWindow: flexibleWindow,
                source: source
            )
        }
    }

    func reset() {
        stopVoiceCapture()
        rawText = ""
        selectedChips = []
        source = .typed
        voiceMessage = nil
        voiceAutoSaveRequestID = nil
        parsedVoiceTasks = []
        needsReview = []
    }

    func stopVoiceCapture() {
        guard isListening else { return }
        voiceRecorder.cancel()
        isListening = false
        voiceMessage = rawText.trimmedForStorage.isEmpty ? "Stopped listening." : readyMessage()
    }

    private static let taskStarterLookahead = #"(?:(?:i\s+)?(?:need|have|want)\s+to\b|(?:i\s+)?(?:gotta|should|must)\b|remember\s+to\b|remind\s+me\s+to\b|don'?t\s+forget\s+to\b|do\s+not\s+forget\s+to\b)"#
    private static let taskStarterPattern = #"(?i)^(?:and\s+|also\s+|then\s+)?(?:(?:i\s+)?(?:need|have|want)\s+to|(?:i\s+)?(?:gotta|should|must)|remember\s+to|remind\s+me\s+to|don'?t\s+forget\s+to|do\s+not\s+forget\s+to)\s+"#
    private static let implicitTaskVerbLookahead = #"(?:(?:go|do|paint|sort|call|pay|clean|buy|get|schedule|book|make|wash|fold|start|finish|email|text|send|write|read|take|put|drop|return|order|prep|prepare|cook|plan|organize|organise|file|review|check|update|water|set|pack|unpack|vacuum|sweep|mop|wipe|declutter|refill|pick\s+up|take\s+out)\b)"#

    private static func captureItems(from text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "•", with: "\n")

        let starterSeparated = insertSeparatorsBeforeRepeatedStarters(in: normalized)
        return starterSeparated
            .split(separator: "\n")
            .flatMap { splitImplicitTaskList(stripTaskStarter(from: String($0))) }
            .compactMap(cleanTaskText)
    }

    private static func insertSeparatorsBeforeRepeatedStarters(in text: String) -> String {
        var separated = text.replacingOccurrences(
            of: #"(?i)[\n;]+"#,
            with: "\n",
            options: .regularExpression
        )
        separated = separated.replacingOccurrences(
            of: #"(?i)\s*,\s*(?:and\s+|also\s+|then\s+)?(?="# + taskStarterLookahead + #")"#,
            with: "\n",
            options: .regularExpression
        )
        separated = separated.replacingOccurrences(
            of: #"(?i)\s+\b(?:and|also|then)\s+(?="# + taskStarterLookahead + #")"#,
            with: "\n",
            options: .regularExpression
        )
        return separated
    }

    private static func splitImplicitTaskList(_ text: String) -> [String] {
        var separated = text.replacingOccurrences(
            of: #"(?i)\s*,\s*(?:and\s+|also\s+|then\s+)?(?="# + implicitTaskVerbLookahead + #")"#,
            with: "\n",
            options: .regularExpression
        )
        separated = separated.replacingOccurrences(
            of: #"(?i)\s+\b(?:and|also|then)\s+(?="# + implicitTaskVerbLookahead + #")"#,
            with: "\n",
            options: .regularExpression
        )
        return separated.split(separator: "\n").map(String.init)
    }

    private static func stripTaskStarter(from text: String) -> String {
        text.replacingOccurrences(
            of: taskStarterPattern,
            with: "",
            options: .regularExpression
        )
    }

    private static func cleanTaskText(_ text: String) -> String? {
        var cleaned = stripTaskStarter(from: text)
            .replacingOccurrences(
                of: #"(?i)^(?:and|also|then)\s+"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: taskTrimCharacters)

        while let last = cleaned.last, ".!,;:".contains(last) {
            cleaned.removeLast()
            cleaned = cleaned.trimmingCharacters(in: taskTrimCharacters)
        }

        guard !cleaned.isEmpty else { return nil }
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    }

    private static var taskTrimCharacters: CharacterSet {
        .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".!,;:-"))
    }

    private func inferredCategory(from text: String) -> TaskCategory {
        let lowercased = text.lowercased()
        if lowercased.contains("laundry") || lowercased.contains("kitchen") || lowercased.contains("dish") {
            return .cleaning
        }
        if lowercased.contains("bill") || lowercased.contains("pay") {
            return .bills
        }
        if lowercased.contains("doctor") || lowercased.contains("appointment") {
            return .appointment
        }
        if lowercased.contains("med") || lowercased.contains("nail") || lowercased.contains("pharmacy") {
            return .wellness
        }
        if lowercased.contains("grocery") || lowercased.contains("store") || lowercased.contains("pick up") {
            return .errand
        }
        if lowercased.contains("dinner") || lowercased.contains("meal") {
            return .meals
        }
        return .other
    }

    private func inferredMinutes(from text: String) -> Int {
        let lowercased = text.lowercased()
        if lowercased.contains("5 min") || lowercased.contains("quick") { return 5 }
        if lowercased.contains("hour") { return 60 }
        if lowercased.contains("call") { return 10 }
        return 15
    }

    private func startVoiceCapture() async {
        textBeforeVoiceCapture = rawText.trimmedForStorage
        parsedVoiceTasks = []
        needsReview = []
        voiceMessage = "Preparing microphone..."

        do {
            try await voiceRecorder.start()
            isListening = true
            voiceMessage = "Recording..."
        } catch {
            isListening = false
            voiceMessage = error.localizedDescription
        }
    }

    private func stopVoiceCaptureAndParse(autosaves: Bool) async {
        guard isListening else { return }
        isListening = false

        do {
            let audioURL = try voiceRecorder.stop()
            voiceMessage = "Transcribing and parsing..."

            defer {
                try? FileManager.default.removeItem(at: audioURL)
            }

            let response = try await voiceDumpService.parseVoiceDump(
                audioURL: audioURL,
                typedText: textBeforeVoiceCapture
            )

            rawText = response.transcript
            parsedVoiceTasks = response.tasks
            needsReview = response.needsReview
            source = .voice

            if parsedVoiceTasks.isEmpty {
                voiceMessage = needsReview.isEmpty ? "No tasks found." : "Needs review: \(needsReview.joined(separator: ", "))"
            } else if autosaves {
                requestVoiceAutoSave()
            } else {
                voiceMessage = readyMessage()
            }
        } catch {
            voiceRecorder.cancel()
            voiceMessage = error.localizedDescription
        }
    }

    private func requestVoiceAutoSave() {
        guard pendingTaskCount > 0 else { return }
        voiceMessage = pendingTaskCount > 1 ? "Saving \(pendingTaskCount) items..." : "Saving item..."
        voiceAutoSaveRequestID = UUID()
    }

    private func readyMessage() -> String {
        pendingTaskCount > 1 ? "\(pendingTaskCount) items ready for inbox." : "Voice capture added."
    }
}

struct VoiceDumpParseResponse: Decodable {
    var transcript: String
    var tasks: [ParsedVoiceTask]
    var needsReview: [String]

    enum CodingKeys: String, CodingKey {
        case transcript
        case tasks
        case needsReview = "needs_review"
    }
}

struct ParsedVoiceTask: Decodable {
    var title: String
    var category: TaskCategory
    var originalPhrase: String
    var estimatedMinutes: Int
    var confidence: Double

    enum CodingKeys: String, CodingKey {
        case title
        case category
        case originalPhrase = "original_phrase"
        case estimatedMinutes = "estimated_minutes"
        case confidence
    }
}

enum VoiceDumpRecorderError: LocalizedError {
    case microphoneDenied
    case recordingUnavailable
    case noRecordingToUpload

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            return "Microphone access is off for Gentle Day. Enable it in Settings to use Tap to speak."
        case .recordingUnavailable:
            return "The microphone recording could not be started."
        case .noRecordingToUpload:
            return "No voice recording was available to upload."
        }
    }
}

enum VoiceDumpAPIError: LocalizedError {
    case badServerURL
    case serverError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .badServerURL:
            return "The voice API URL is not configured correctly."
        case .serverError(let message):
            return message
        case .invalidResponse:
            return "The voice API returned an unexpected response."
        }
    }
}

@MainActor
final class VoiceDumpRecorder {
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    func start() async throws {
        try await requestMicrophonePermission()
        cancel()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .spokenAudio, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("gentle-day-voice-\(UUID().uuidString)")
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.prepareToRecord()

        guard recorder.record() else {
            throw VoiceDumpRecorderError.recordingUnavailable
        }

        self.recorder = recorder
        self.recordingURL = url
    }

    func stop() throws -> URL {
        guard let recorder, let recordingURL else {
            throw VoiceDumpRecorderError.noRecordingToUpload
        }

        recorder.stop()
        self.recorder = nil
        self.recordingURL = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return recordingURL
    }

    func cancel() {
        recorder?.stop()
        recorder = nil

        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recordingURL = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestMicrophonePermission() async throws {
        let allowed = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }

        guard allowed else {
            throw VoiceDumpRecorderError.microphoneDenied
        }
    }
}

struct VoiceDumpAPIService {
    static var defaultBaseURL: URL {
        let configuredURL = Bundle.main.object(forInfoDictionaryKey: "GentleDayVoiceAPIBaseURL") as? String
        return URL(string: configuredURL ?? "http://localhost:8787")!
    }

    var baseURL: URL = VoiceDumpAPIService.defaultBaseURL

    func parseVoiceDump(audioURL: URL, typedText: String) async throws -> VoiceDumpParseResponse {
        let endpoint = baseURL.appendingPathComponent("api/voice-dump")
        var request = URLRequest(url: endpoint)
        let boundary = "Boundary-\(UUID().uuidString)"

        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90

        let body = try makeMultipartBody(
            boundary: boundary,
            audioURL: audioURL,
            typedText: typedText
        )

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceDumpAPIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let serverError = try? JSONDecoder().decode(VoiceDumpServerError.self, from: data)
            throw VoiceDumpAPIError.serverError(serverError?.error ?? "Voice API failed with HTTP \(httpResponse.statusCode).")
        }

        return try JSONDecoder().decode(VoiceDumpParseResponse.self, from: data)
    }

    private func makeMultipartBody(boundary: String, audioURL: URL, typedText: String) throws -> Data {
        var body = Data()
        body.appendFormField(name: "typed_text", value: typedText, boundary: boundary)
        body.appendFileField(
            name: "audio",
            filename: audioURL.lastPathComponent,
            mimeType: "audio/m4a",
            data: try Data(contentsOf: audioURL),
            boundary: boundary
        )
        body.appendString("--\(boundary)--\r\n")
        return body
    }
}

private struct VoiceDumpServerError: Decodable {
    var error: String
}

private extension Data {
    mutating func appendFormField(name: String, value: String, boundary: String) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        appendString("\(value)\r\n")
    }

    mutating func appendFileField(
        name: String,
        filename: String,
        mimeType: String,
        data: Data,
        boundary: String
    ) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        appendString("Content-Type: \(mimeType)\r\n\r\n")
        append(data)
        appendString("\r\n")
    }

    mutating func appendString(_ string: String) {
        append(Data(string.utf8))
    }
}
