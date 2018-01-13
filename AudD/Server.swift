//
//  Server.swift
//  AudD
//
//  Created by Aleksei Gordeev on 13/01/2018.
//  Copyright © 2018 Dialog. All rights reserved.
//

import Foundation
import RxSwift


public class Server {
    
    public let shared = Server.init(apiToken: AudDApiKey)
    
    public let uid: String
    
    private let apiToken: String
    
    private let base = URL.init(string: "https://api.audd.io")!
    
    private let bag = DisposeBag.init()
    
    public init(apiToken: String) {
        self.apiToken = apiToken
        
        self.uid = "com.vladlex.AudD.u{\(UserDefaults.standard.auddUserId)}"
    }
    
    public func perform(_ request: Request) {
        switch request {
        case .findAudio(config: let config):
            self.findAudio(config)
        }
    }
    
    private func findAudio(_ config: Request.FindAudioConfig) {
        
        var urlBuild = URLComponents.init(url: self.base, resolvingAgainstBaseURL: false)!
        
        var queryItems: [URLQueryItem] = []
        
        if let method = config.method {
            queryItems.append(.init(name: "method", value: method.proposedMethodName))
        }
        
        if let format = config.format {
            queryItems.append(.init(name: "audio_format", value: format))
        }
        config.resultType.proposedQueryItemNames.forEach {
            queryItems.append(.init(name: $0, value: nil))
        }
        
        queryItems.append(.init(name: "api_token", value: self.apiToken))
        
        urlBuild.queryItems = queryItems
        
        let url = urlBuild.url!
        let request = URLRequest.init(url: url)
        
        URLSession.shared.rx.json(request: request).subscribe(onNext: { (obj) in
            print("loaded: \(obj)")
        }, onError: { (error) in
            print("failed: \(error)")
        }, onCompleted: {
            print("completed")
        }).disposed(by: self.bag)
    }
    
    public enum Request {
        case findAudio(config: FindAudioConfig)
        
        public struct FindAudioConfig {
            public let source: FindAudioSource
            
            public var resultType: FindAudioResultType = [FindAudioResultType.itunes]
            public var method: FindAudioMethod? = nil
            public var format: String? = nil
            public var uid: String? = nil
            
            public init(source: FindAudioSource) {
                self.source = source
            }
            
        }
        
    }
    
    public enum FindAudioSource {
        case remoteUrl(URL)
        case localFile(URL)
        case cache(uid: String)
    }
    
    public enum FindAudioMethod: Int {
        case byOriginalSong
        case byUserReproduce
        
        fileprivate var proposedMethodName: String {
            switch self {
            case .byOriginalSong: return "audd.api.recognize"
            case .byUserReproduce: return "audd.api.recognizeWithOffset"
            }
        }
    }
    
    public struct FindAudioResultType: OptionSet {
        
        public typealias RawValue = Int
        
        public let rawValue: Int
        
        public init(rawValue: FindAudioResultType.RawValue) {
            self.rawValue = rawValue
        }
        
        public static let itunes = FindAudioResultType.init(rawValue: 1 << 0)
        
        public static let vk = FindAudioResultType.init(rawValue: 1 << 1)
        
        public static let lyrics = FindAudioResultType.init(rawValue: 1 << 2)
        
        public static let none: FindAudioResultType = []
        
        public static let all: FindAudioResultType = [.itunes, .vk, .lyrics]
        
        fileprivate var proposedQueryItemNames: [String] {
            var names: [String] = []
            if self.contains(.itunes) {
                names.append("return_itunes_audios")
            }
            if self.contains(.vk) {
                names.append("return_vk_audios")
            }
            if self.contains(.lyrics) {
                names.append("return_lyrics")
            }
            return names
        }
    }
    
}






