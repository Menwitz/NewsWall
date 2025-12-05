import Foundation
import Speech
import AVFoundation

class TranscriptionEngine: NSObject {
    static let shared = TranscriptionEngine()
    
    private var recognizers: [UUID: SFSpeechRecognizer] = [:]
    private var recognitionTasks: [UUID: SFSpeechRecognitionTask] = [:]
    private var audioEngines: [UUID: AVAudioEngine] = [:]
    
    // Keyword alert system
    var keywordAlerts: [String] = [] {
        didSet { UserDefaults.standard.set(keywordAlerts, forKey: "keywordAlerts") }
    }
    
    // Transcription callback
    var onTranscription: ((UUID, String) -> Void)?
    var onKeywordDetected: ((UUID, String, String) -> Void)? // channelID, keyword, full text
    
    private override init() {
        super.init()
        
        // Load saved keywords
        if let saved = UserDefaults.standard.array(forKey: "keywordAlerts") as? [String] {
            keywordAlerts = saved
        }
        
        // Request authorization
        SFSpeechRecognizer.requestAuthorization { status in
            print("Speech recognition authorization: \(status.rawValue)")
        }
    }
    
    func startTranscribing(channelID: UUID, audioNode: AVAudioNode?) {
        // Stop any existing transcription for this channel
        stopTranscribing(channelID: channelID)
        
        guard let audioNode = audioNode else { return }
        
        // Create recognizer (defaults to device locale, can specify language)
        let recognizer = SFSpeechRecognizer()
        guard let recognizer = recognizer, recognizer.isAvailable else {
            print("Speech recognizer not available")
            return
        }
        
        recognizers[channelID] = recognizer
        
        // Create audio engine
        let audioEngine = AVAudioEngine()
        audioEngines[channelID] = audioEngine
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false // Use cloud for better accuracy
        
        // Tap into audio
        let recordingFormat = audioNode.outputFormat(forBus: 0)
        audioNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        
        // Start recognition
        let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                
                // Notify about transcription
                DispatchQueue.main.async {
                    self.onTranscription?(channelID, transcription)
                }
                
                // Check for keywords
                self.checkForKeywords(channelID: channelID, text: transcription)
            }
            
            if error != nil || result?.isFinal == true {
                // Restart transcription if it stops
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.startTranscribing(channelID: channelID, audioNode: audioNode)
                }
            }
        }
        
        recognitionTasks[channelID] = task
        
        // Start audio engine
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine failed to start: \(error)")
        }
    }
    
    func stopTranscribing(channelID: UUID) {
        recognitionTasks[channelID]?.cancel()
        recognitionTasks.removeValue(forKey: channelID)
        
        audioEngines[channelID]?.stop()
        audioEngines.removeValue(forKey: channelID)
        
        recognizers.removeValue(forKey: channelID)
    }
    
    private func checkForKeywords(channelID: UUID, text: String) {
        let lowercasedText = text.lowercased()
        
        for keyword in keywordAlerts {
            let lowercasedKeyword = keyword.lowercased()
            if lowercasedText.contains(lowercasedKeyword) {
                DispatchQueue.main.async {
                    self.onKeywordDetected?(channelID, keyword, text)
                }
            }
        }
    }
    
    func addKeyword(_ keyword: String) {
        if !keywordAlerts.contains(keyword) {
            keywordAlerts.append(keyword)
        }
    }
    
    func removeKeyword(_ keyword: String) {
        keywordAlerts.removeAll { $0 == keyword }
    }
}
