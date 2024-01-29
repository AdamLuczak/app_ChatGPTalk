//
//  AL_SpeachToTokens.swift
//  vAssistant
//
//  Created by Adam Łuczak on 08/06/2022.
//

import AVFoundation
import Foundation
import Speech
import SwiftUI
import NaturalLanguage

protocol speachToTextDelegate
{
    func transcript(text:String)
}

class speachToText: ObservableObject
{
    enum RecognizerError: Error
    {
        case nilRecognizer
        case notAuthorizedToRecognize
        case notPermittedToRecord
        case recognizerIsUnavailable
        
        var message: String
        {
            switch self
            {
            case .nilRecognizer: return "Can't initialize speech recognizer"
            case .notAuthorizedToRecognize: return "Not authorized to recognize speech"
            case .notPermittedToRecord: return "Not permitted to record audio"
            case .recognizerIsUnavailable: return "Recognizer is unavailable"
            }
        }
    }
    
    @Published  var transcript:     String                                  = ""

    private     let tokenizer       = NLTokenizer(unit: .word)

    private     var audioEngine:    AVAudioEngine?
    private     var request:        SFSpeechAudioBufferRecognitionRequest?
    private     var task:           SFSpeechRecognitionTask?
    private     let recognizer:     SFSpeechRecognizer?                     = SFSpeechRecognizer(locale: Locale.init(identifier: "en-US"))

    public      var delegate:       speachToTextDelegate?
    static      var shared:         speachToText                            = speachToText()
    
    init()
    {
        let session: AVAudioSession = AVAudioSession.sharedInstance()
        do
        {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord)
            try session.setActive(true)
        }
        catch
        {
            print("Couldn't override output audio port")
        }

        print("Init spech recognizer")

        tokenizer.setLanguage(.polish)

        Task(priority: .background)
        {
            do
            {
                guard recognizer != nil else
                {
                    throw RecognizerError.nilRecognizer
                    print("recognizer == nil")
                }
                
                guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else
                {
                    throw RecognizerError.notAuthorizedToRecognize
                    print("recognizer is not autorised")
                }
                
                guard await AVAudioSession.sharedInstance().hasPermissionToRecord() else
                {
                    throw RecognizerError.notPermittedToRecord
                    print("recognizer is not permitted")

                }
                
                try? AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord)
            }
            catch
            {
                print("erro ",error)

                speakError(error)
            }
        }
    }
    
    deinit
    {
        reset()
    }
    
    func transcribe()
    {
        DispatchQueue(label: "Speech Recognizer Queue", qos: .background).async
        { [weak self] in
            
            guard let self = self, let recognizer = self.recognizer, recognizer.isAvailable else
            {
                print("not available")
                self?.speakError(RecognizerError.recognizerIsUnavailable)
                return
            }
                
            do
            {
                recognizer.supportsOnDeviceRecognition = true // ensure the DEVICE does the work -- don't send to cloud
                recognizer.defaultTaskHint             = .dictation // give a hint as dictation

                let (audioEngine, request) = try Self.prepareEngine()
                
                print(request)

                self.audioEngine    = audioEngine
                self.request        = request
                
                
                //print("on devie", recognizer.supportsOnDeviceRecognition);
                //self.request!.requiresOnDeviceRecognition = true
                
                self.task           = recognizer.recognitionTask(with: request, resultHandler: self.recognitionHandler(result:error:))

                try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord)
                print("ok")
            }
            catch
            {
                self.reset()
                self.speakError(error)
            }
        }
    }

    func stopTranscribing()
    {
        reset()
    }
    
    func reset()
    {
        task?.cancel()
        audioEngine?.stop()
        audioEngine         = nil
        request             = nil
        task                = nil
    }

    private static func prepareEngine() throws -> (AVAudioEngine, SFSpeechAudioBufferRecognitionRequest)
    {
        let audioEngine                         = AVAudioEngine()
        
        let request                             = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults      = true

        let audioSession                        = AVAudioSession.sharedInstance()
        
        //try audioSession.setCategory    (.record, mode: .measurement, options: .interruptSpokenAudioAndMixWithOthers)
        try audioSession.setCategory    (AVAudioSession.Category.playAndRecord)

        try audioSession.setActive      (true)//, options: .notifyOthersOnDeactivation)
        
        let inputNode                       = audioEngine.inputNode
        let recordingFormat                 = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat)
        { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            request.append(buffer)
        }
        
        audioEngine.prepare()
        
        do
        {
            try audioEngine.start()
        }
        catch
        {
            print("cannot start speach recognizer")
        }
        print("start recognition")
        
        return (audioEngine, request)
    }

    private func recognitionHandler(result: SFSpeechRecognitionResult?, error: Error?)
    {
        var isFinal = false
        
        if let result = result
        {
            isFinal = result.isFinal
            
            let text                = result.bestTranscription.formattedString
            let fullStringRange     = text.startIndex..<text.endIndex
            
            self.tokenizer.string   = text

            let tokens_range        = tokenizer.tokens(for: fullStringRange)
            let tokens              = tokens_range.map{ text[$0] }
            
            print(tokens)

            if tokens.count > 0 && (tokens.last == "ok" || tokens.last == "OK")
            {
                DispatchQueue.main.async
                {
                    var tx = tokens
                        tx.removeLast()
                    self.transcript = String(tx.joined(separator: " "))
                    if self.delegate != nil
                    {
                        self.delegate!.transcript(text:self.transcript)
                    }
                }
                stopTranscribing()
            }
        }
        
        if error != nil// || isFinal
        {
            // Stop recognizing speech if there is a problem.
            //self.audioEngine!.stop()
      //      inputNode.removeTap(onBus: 0)

            //self.request = nil
//            self.recognitionTask = nil

  //          self.recordButton.isEnabled = true
    //        self.recordButton.setTitle("Start Recording", for: [])
        }
/*
        let receivedFinalResult = result?.isFinal ?? false
        let receivedError       = error != nil
        
        print(error)
        
        if receivedFinalResult || receivedError
        {
            print("stop")
                audioEngine?.stop()
            audioEngine?.inputNode.removeTap(onBus: 0)
        }
        
        if let result = result
        {
            print("new text")
            speak(result.bestTranscription.formattedString)
        }
        else
        {
            print("error")
        }
 */
    }
    
    private func speak(_ message: String)
    {
        print(message)
        transcript = message
    }
    
    private func speakError(_ error: Error)
    {
         var errorMessage = ""
    
        if let error = error as? RecognizerError
        {
             errorMessage += error.message
        }
        else
        {
             errorMessage += error.localizedDescription
        }
        
        transcript = "<< \(errorMessage) >>"
     }
    
}

extension SFSpeechRecognizer
{
    static func hasAuthorizationToRecognize() async -> Bool
    {
        await withCheckedContinuation
        { continuation in
            requestAuthorization
            { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

extension AVAudioSession
{
    func hasPermissionToRecord() async -> Bool
    {
        await withCheckedContinuation
        { continuation in
            requestRecordPermission
            { authorized in
                continuation.resume(returning: authorized)
            }
        }
    }
}
