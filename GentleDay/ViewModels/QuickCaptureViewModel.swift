import AVFoundation
import Foundation
import Observation
import Speech

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

    @ObservationIgnored private let liveSpeechTranscriber = LiveSpeechTranscriber()
    @ObservationIgnored private let voiceDumpService = VoiceDumpAPIService()
    @ObservationIgnored private var textBeforeVoiceCapture = ""
    @ObservationIgnored private var recognizedVoiceText = ""

    var canSave: Bool {
        !rawText.trimmedForStorage.isEmpty
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
        return Self.captureItems(from: rawText).count
    }

    func toggle(_ chip: QuickCaptureChip) {
        if selectedChips.contains(chip) {
            selectedChips.remove(chip)
        } else {
            selectedChips.insert(chip)
        }
    }

    func makeTasks() -> [TaskItem] {
        let selectedCategory = selectedChips.compactMap(\.category).first
        let selectedMinutes = selectedChips.compactMap(\.minutes).first
        let dueDate = selectedChips.compactMap(\.dueDateOffset).min().flatMap { offset in
            Calendar.current.date(byAdding: .day, value: offset, to: Date())
        }
        let flexibleWindow = selectedChips.compactMap(\.flexibleWindow).first

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
        recognizedVoiceText = ""
    }

    func stopVoiceCapture() {
        guard isListening else { return }
        liveSpeechTranscriber.cancel()
        isListening = false
        recognizedVoiceText = ""
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
        if lowercased.contains("trash") { return 10 }
        if lowercased.contains("call") { return 10 }
        return 15
    }

    func startVoiceCapture() async {
        textBeforeVoiceCapture = rawText.trimmedForStorage
        recognizedVoiceText = ""
        voiceMessage = "Preparing speech..."

        do {
            try await liveSpeechTranscriber.start(
                onTranscript: { [weak self] transcript in
                    guard let self else { return }
                    self.recognizedVoiceText = transcript.trimmedForStorage
                    self.updateRawTextWithRecognizedVoiceText()
                    self.source = .voice
                    self.voiceMessage = self.recognizedVoiceText.isEmpty ? "Listening..." : "Filling text live..."
                },
                onError: { [weak self] error in
                    self?.voiceMessage = error.localizedDescription
                }
            )
            isListening = true
            voiceMessage = "Listening... words will appear above."
        } catch {
            isListening = false
            voiceMessage = error.localizedDescription
        }
    }

    func stopVoiceCaptureAndParseForPreview(
        preferences: UserPlanningPreferences?,
        existingTasks: [TaskItem],
        existingScheduleBlocks: [ScheduleBlock]
    ) async throws -> AITaskParseResponse? {
        guard isListening else { return nil }
        isListening = false

        do {
            let finalTranscript = liveSpeechTranscriber.stop().trimmedForStorage
            if !finalTranscript.isEmpty {
                recognizedVoiceText = finalTranscript
                updateRawTextWithRecognizedVoiceText()
            }

            let transcript = rawText.trimmedForStorage
            guard !transcript.isEmpty else {
                voiceMessage = "No speech was recognized. Check Speech Recognition access in Settings."
                return nil
            }

            voiceMessage = "Parsing tasks..."
            guard let preferences else {
                voiceMessage = "Settings are still loading. Please try again in a moment."
                return nil
            }

            guard preferences.enableAIParsing else {
                voiceMessage = AIParsingFeatureError.disabled.localizedDescription
                return nil
            }

            let response = try await voiceDumpService.parseTextDump(
                transcript,
                preferences: preferences,
                existingTasks: existingTasks,
                existingScheduleBlocks: existingScheduleBlocks
            )

            rawText = transcript
            source = .voice
            recognizedVoiceText = ""
            voiceMessage = response.friendlySummary

            return response
        } catch {
            liveSpeechTranscriber.cancel()
            voiceMessage = error.localizedDescription
            throw error
        }
    }

    private func updateRawTextWithRecognizedVoiceText() {
        rawText = [textBeforeVoiceCapture, recognizedVoiceText]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private func readyMessage() -> String {
        pendingTaskCount > 1 ? "\(pendingTaskCount) items ready for inbox." : "Voice capture added."
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

enum LiveSpeechTranscriberError: LocalizedError {
    case microphoneDenied
    case speechDenied
    case speechRestricted
    case speechUnavailable
    case audioInputUnavailable

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            return "Microphone access is off for Gentle Day. Enable it in Settings to use Tap to speak."
        case .speechDenied:
            return "Speech recognition is off for Gentle Day. Enable it in Settings to use live dictation."
        case .speechRestricted:
            return "Speech recognition is restricted on this device."
        case .speechUnavailable:
            return "Speech recognition is temporarily unavailable. Try again in a moment."
        case .audioInputUnavailable:
            return "The microphone input is unavailable."
        }
    }
}

@MainActor
final class LiveSpeechTranscriber {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var currentTranscript = ""
    private var isActive = false
    private var onTranscript: ((String) -> Void)?
    private var onError: ((Error) -> Void)?

    func start(
        onTranscript: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) async throws {
        try await requestPermissions()
        cancel()

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw LiveSpeechTranscriberError.speechUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.taskHint = .dictation
        request.contextualStrings = [
            "grocery shopping",
            "dishes",
            "paint my nails",
            "sort my meds",
            "laundry",
            "appointment",
            "errands"
        ]

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0 else {
            throw LiveSpeechTranscriberError.audioInputUnavailable
        }

        self.recognitionRequest = request
        self.currentTranscript = ""
        self.isActive = true
        self.onTranscript = onTranscript
        self.onError = onError

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let result {
                    self.currentTranscript = result.bestTranscription.formattedString
                    self.onTranscript?(self.currentTranscript)
                }

                if let error, self.isActive {
                    self.onError?(error)
                }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    func stop() -> String {
        guard isActive else { return currentTranscript }
        isActive = false

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        recognitionRequest = nil
        recognitionTask = nil
        onTranscript = nil
        onError = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        return currentTranscript
    }

    func cancel() {
        isActive = false

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        currentTranscript = ""
        onTranscript = nil
        onError = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestPermissions() async throws {
        try await requestMicrophonePermission()
        try await requestSpeechPermission()
    }

    private func requestMicrophonePermission() async throws {
        let allowed = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }

        guard allowed else {
            throw LiveSpeechTranscriberError.microphoneDenied
        }
    }

    private func requestSpeechPermission() async throws {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        switch status {
        case .authorized:
            return
        case .denied:
            throw LiveSpeechTranscriberError.speechDenied
        case .restricted:
            throw LiveSpeechTranscriberError.speechRestricted
        case .notDetermined:
            throw LiveSpeechTranscriberError.speechDenied
        @unknown default:
            throw LiveSpeechTranscriberError.speechUnavailable
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
    @MainActor
    func parseTextDump(
        _ text: String,
        preferences: UserPlanningPreferences,
        existingTasks: [TaskItem],
        existingScheduleBlocks: [ScheduleBlock]
    ) async throws -> AITaskParseResponse {
        let context = AIParsingContext(
            currentDate: Date(),
            timezone: TimeZone.current.identifier,
            locale: Locale.current.identifier,
            planningDay: .today,
            planningStyle: .balancedDay,
            preferences: preferences,
            existingTasks: existingTasks,
            existingScheduleBlocks: existingScheduleBlocks
        )
        let service = AIParsingServiceFactory.makeService(preferences: preferences)
        return try await service.parseTaskCapture(rawText: text, context: context)
    }
}
