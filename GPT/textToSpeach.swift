//
//  textToSpeach.swift
//  chessWithAI
//
//  Created by Adam Łuczak on 05/01/2023.
//

import Foundation
import SwiftUI
import AVFoundation

class textToSpeach:ObservableObject
{
    private     var speechSynthesizer   = AVSpeechSynthesizer()
    private     let voice               = AVSpeechSynthesisVoice(language: "English")
    
    static      var shared              = textToSpeach()
    
    init()
    {
        print("text to speach started")
    }
    
    func speak(text:String)
    {
        if self.speechSynthesizer.isSpeaking
        {
            self.speechSynthesizer.stopSpeaking(at: .word)
        }

        let audioSession: AVAudioSession = AVAudioSession.sharedInstance()

        try? audioSession.setCategory    (.playback)
        try? audioSession.setActive      (true)//, options: .notifyOthersOnDeactivation)

        let utterance           = AVSpeechUtterance(string: text)
            utterance.voice     = self.voice

        self.speechSynthesizer.speak(utterance)
    }
}
