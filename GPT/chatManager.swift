//
//  chatManager.swift
//  chessWithAI
//
//  Created by Adam Łuczak on 05/01/2023.
//

import Foundation
import Combine

struct chatUsage:Decodable
{
    var prompt_tokens       :Int
    var completion_tokens   :Int
    var total_tokens        :Int
}

struct chatMsg:Decodable
{
    var role:String
    var content:String
}

struct chatAns:Decodable
{
    var index:Int
    var message:chatMsg?
    var logprobs:String?
    var finish_reason:String
}

struct chatResp:Decodable
{
    var id      :String
    var object  :String
    var created :Int64
    var model   :String
    var choices :[chatAns]
    var usage   :chatUsage
}

protocol ChatRequestManagerDelegate
{
    func answer(ans:String)
}

class ChatRequestManager: ObservableObject
{
    private     var cancellables    = Set<AnyCancellable>()
    private     var cfg             = cfgGloabal.shared
    @Published  var responseDict: chatResp?
    @Published  var responseData: Data?
    @Published  var responseError: Error?
    
    public      var delegate:ChatRequestManagerDelegate?
    
    func makeRequest(text: String)
    {
        let apiKey              = cfg.apiKey//"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"
        let model               = cfg.version//"text-davinci-003"
        let prompt              = text
        let temperature         = 0.9
        let maxTokens           = 150
        let topP                = 1
        let frequencyPenalty    = 0.0
        let presencePenalty     = 0.6
        let stop                = [" Human:", " AI:"]
        
        let requestBody : [String : Any] = [
            "model"             : model,
            "messages"          : [ ["role":"system","content":"You are a helpful assistant"], ["role":"user","content":prompt] ],
            "temperature"       : temperature,
            "max_tokens"        : maxTokens,
            "top_p"             : topP,
            "frequency_penalty" : frequencyPenalty,
            "presence_penalty"  : presencePenalty,
            "stop"              : stop
        ]
        
        let jsonData    = try? JSONSerialization.data(withJSONObject: requestBody)
        
        var request     = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = jsonData
        
        URLSession.shared
            .dataTaskPublisher(for: request)
            .map { $0.data }
            .sink(receiveCompletion:
                { completion in
                    switch completion
                    {
                        case .failure(let err):
                            self.responseError = err
                            
                        default:
                            break;
                    }
                }, receiveValue: { data in
                    DispatchQueue.main.async
                    {
                        let ans             = String(decoding: data, as: UTF8.self)
                        
                        print(ans)
                     
                        let decoder         = JSONDecoder()
                        var res             = try! decoder.decode(chatResp.self, from: data)
                     
                        if var message = res.choices[0].message?.content
                        {
                            if message.hasPrefix("?\n\n")
                            {
                                message.replace("?\n\n", with: "", maxReplacements: 1)
                            }
                            
                            if message.hasPrefix(" ?\n\n")
                            {
                                message.replace(" ?\n\n", with: "", maxReplacements: 1)
                            }
                             
                            self.responseDict = res
                            self.responseData = data
                             
                            if self.delegate != nil
                            {
                                self.delegate!.answer(ans: message)
                            }
                        }
                    }
            })
            .store(in: &self.cancellables)
    }
}
