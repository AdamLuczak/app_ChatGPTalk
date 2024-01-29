//
//  ContentView.swift
//  chessWithAI
//
//  Created by Adam Łuczak on 05/01/2023.
//

import SwiftUI
import AVFoundation
import CoreAudio
import Combine

enum gptVersion : String, CaseIterable
{
    case m1 = "gpt-4"
    case m2 = "gpt-4-0125-preview"
    case m3 = "gpt-4-turbo-preview"
    case m4 = "gpt-4-1106-preview"
    case m5 = "gpt-3.5-turbo-1106"
    case m6 = "gpt-3.5-turbo"
    case m7 = "gpt-3.5-turbo-16k"
}

class cfgGloabal:ObservableObject
{
    private         var cancellables        = Set<AnyCancellable>()
    private         var defaults            = UserDefaults.standard
    @Published      var apiKey:String       = ""
    @Published      var version:String      = gptVersion.m1.rawValue
    
    static          var shared              = cfgGloabal()
    
    init()
    {
        self.apiKey     = defaults.string(forKey: "apiKey")     ?? ""
        self.version    = defaults.string(forKey: "version")    ?? gptVersion.m1.rawValue

        $apiKey
            .sink
            { text in
                self.defaults.set(text, forKey: "apiKey")
            }
            .store(in: &self.cancellables)

        $version
            .sink
            { text in
                print(text)
                self.defaults.set(text, forKey: "version")
            }
            .store(in: &self.cancellables)
    }
}

class chatManager:ObservableObject, ChatRequestManagerDelegate, speachToTextDelegate
{
    @ObservedObject var apiRequestManager       = ChatRequestManager()
    private         let text_to_speach          = textToSpeach()
    private         let speach_to_text          = speachToText()

    @Published      var isTextToSpeachEnabled   = true
    @Published      var isSpeachToTextEnabled   = false
    @Published      var isRecording             = false
    @Published      var text:String             = ""
    @Published      var query:String            = ""

    static          var shared                  = chatManager()
    
    init()
    {
        let session: AVAudioSession = AVAudioSession.sharedInstance()
        do
        {
            try session.setCategory(AVAudioSession.Category.playAndRecord)
//            try session.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
            try session.setActive(true)
        }
        catch
        {
            print("Couldn't override output audio port")
        }
        
        apiRequestManager.delegate  = self
        speach_to_text.delegate     = self
    }
    
    func startRecording()
    {
        speach_to_text.transcribe()
    }
    
    func answer(ans:String)
    {
        if self.isTextToSpeachEnabled
        {
            textToSpeach.shared.speak(text: ans)
            text = ans
        }
    }
    
    func transcript(text: String)
    {
        query       = text
        isRecording = false
        self.apiRequestManager.makeRequest(text: self.query)
    }
}

struct ContentView: View
{
    @ObservedObject var manager             = chatManager.shared

    var body: some View
    {
        
        NavigationStack
        {
            HStack
            {
                Button(
                    action:
                        {
                            manager.isSpeachToTextEnabled.toggle()
                        },
                    label:
                        {
                            Image(systemName: manager.isSpeachToTextEnabled ? "music.mic.circle.fill" : "mic.slash.circle.fill")
                                .resizable()
                                .foregroundColor(Color.orange)
                                .frame(width: 48,height: 48)
                        })
                
                Button(
                    action:
                        {
                            manager.isTextToSpeachEnabled.toggle()
                        },
                    label:
                        {
                            Image(systemName: manager.isTextToSpeachEnabled ? "speaker.wave.2.circle.fill" : "speaker.slash.circle.fill")
                                .resizable()
                                .foregroundColor(Color.orange)
                                .frame(width: 48,height: 48)
                        })
                
                Spacer()
                
                NavigationLink(
                    destination: configView(),
                    label:
                        {
                            Image(systemName: "gearshape.fill")
                                .resizable()
                                .foregroundColor(Color.orange)
                                .frame(width: 48,height: 48)
                        })
            }
            .padding()
            
            HStack
            {
                TextField("Ask...", text: $manager.query, axis: .vertical)
                    .frame(minHeight: 64)
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 10.0).strokeBorder(Color.orange, style: StrokeStyle(lineWidth: 1.5)))
                    .padding()
                
                if manager.isSpeachToTextEnabled
                {
                    Button(
                        action:
                            {
                                if !manager.isRecording
                                {
                                    manager.isRecording = true
                                    manager.startRecording()
                                    manager.query       = ""
                                    manager.text        = ""
                                }
                            },
                        label:
                            {
                                Image(systemName: manager.isRecording ? "mic.fill":"mic")
                                    .resizable()
                                    .foregroundColor(manager.isRecording ? Color.red : Color.orange)
                                    .frame(width: 48,height: 48)
                            })
                    .padding()
                }
            }

            if !manager.isSpeachToTextEnabled
            {
                Button(action:
                        {
                    manager.apiRequestManager.makeRequest(text: manager.query)
                }) {
                    Text("Ask MobGPT")
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .font(.system(size: 18))
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding()
                }
                .padding(4)
                .background(Color.orange)
                .cornerRadius(20)
                .padding()
            }

            Text(manager.text)
                .padding()
                .frame(maxWidth: .infinity)
            
            Spacer()
        }
        .accentColor(.orange)
    }
}

struct ContentView_Previews: PreviewProvider
{
    static var previews: some View
    {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

struct configView: View
{
    @ObservedObject var cfg = cfgGloabal.shared
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    var body: some View
    {
        VStack
        {
            List
            {
                Section("chatGTP ApiKey")
                {
                    TextField("key",text: $cfg.apiKey, axis: .vertical)
                }
                .foregroundColor(.orange)

                Section("chatGTP version")
                {
                    Picker( selection: $cfg.version,
                            content:
                            {
                                ForEach(gptVersion.allCases, id: \.self)
                                { item in
                                    Text(item.rawValue.capitalized)
                                        .tag(item.rawValue)
                                }
                            },
                            label: {})
                }
                .foregroundColor(.orange)
            }
            
            Spacer()
            
            Button(
                action:
                {
                    self.presentationMode.wrappedValue.dismiss()
                },
                label:
                    {
                        Text("Save")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.orange)
                            .foregroundColor(.black)
                            .clipShape(Capsule())
                    })
        }
        .accentColor(.orange)
    }
}
