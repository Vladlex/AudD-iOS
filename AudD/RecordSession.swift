//
//  RecordSession.swift
//  AudD
//
//  Created by Aleksei Gordeev on 13/01/2018.
//  Copyright © 2018 Dialog. All rights reserved.
//

import Foundation
import AVFoundation
import RxSwift


/**
 Responsible for recording audio in file.
 */
public final class RecordSession {
    
    /**
     Removes old redords in documents directory.
     TODO: Move to separate class to manage (save results, removing records).
 */
    public static func removeOldRecords() {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let urls = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [])
        
        if let urls = urls {
            for url in urls {
                try? FileManager.default.removeItem(at: url)
            }
            if urls.count > 0 {
                print("\(urls.count) files removed")
            }
        }
    }
    
    /**
     Generates random file with new UUID as a name and with given extension
     */
    public static func randomFileUrl(fileExtension: String) -> URL {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        return folder.appendingPathComponent(UUID().uuidString, isDirectory: false).appendingPathExtension(fileExtension)
    }
    
    
    public struct Config {
        
        public var bitRate: Int = 192000
        
        public var sampleRate: Double = 44100.0
        
        public var channels: Int = 1
        
        public var format: Format = .appleLossless
        
        public var quality: Quality = .medium
        
        public static let `default` = Config()
        
        public enum Format {
            case appleLossless
            case wav
            
            /// Representation to use for AVAudioRecorder settings
            fileprivate var settingsValueRepresentation: AnyObject {
                switch self {
                case .appleLossless: return kAudioFormatAppleLossless as AnyObject
                case .wav: return kAudioFormatLinearPCM as AnyObject
                }
            }
            
            fileprivate var proposedFileExtension: String {
                switch self {
                case .appleLossless: return "flac"
                case .wav: return "wav"
                }
            }
        }
        
        public enum Quality: Int {
            case max
            case medium
            
            /// Representation to use for AVAudioRecorder settings
            fileprivate var settingsValueRepresentation: AnyObject {
                switch self {
                case .max: return AVAudioQuality.max.rawValue as AnyObject
                case .medium: return AVAudioQuality.medium.rawValue as AnyObject
                }
            }
        }
        
        /// Representation to use for AVAudioRecorder settings
        fileprivate var dictionaryRepresentation: [String : AnyObject] {
            return [
                AVFormatIDKey : self.format.settingsValueRepresentation,
                AVEncoderAudioQualityKey : self.quality.settingsValueRepresentation,
                AVEncoderBitRateKey : self.bitRate as AnyObject,
                AVNumberOfChannelsKey : self.channels as AnyObject,
                AVSampleRateKey : self.bitRate as AnyObject
            ]
        }
    }
    
    public enum State: CustomStringConvertible {
        case idle
        case preparing
        case recording(meters:[Float])
        case recorded
        case failed(Error)
        case cancelled
        
        private var id: Int {
            switch self {
            case .idle: return 1
            case .preparing: return 2
            case .recording(meters: _): return 3
            case .recorded: return 4
            case .failed(_): return 5
            case .cancelled: return 6
            }
        }
        
        var isFinal: Bool {
            switch self {
            case .failed(_): return true
            case .recorded: return true
            case .cancelled: return true
            default: return false
            }
        }
        
        public var isPreparing: Bool {
            switch self {
            case .preparing: return true
            default: return false
            }
        }
        
        public var isIdle: Bool {
            switch self {
            case .idle: return true
            default: return false
            }
        }
        
        public var description: String {
            switch self {
            case .idle: return "Idle"
            case .cancelled: return "Cancelled"
            case .failed(let error): return "Failed. \(error)"
            case .preparing: return "Preparing"
            case .recorded: return "Recorded"
            case .recording(meters: _): return "Recording"
            }
        }
        
    }
    
    public private(set) var state: State = .idle {
        didSet {
            guard !oldValue.isFinal else {
                return
            }
            print("Record state: \(state)")
            switch state {
            case .failed(let error):
                self.publisher.onError(error)
            default:
                self.publisher.onNext(state)
                if state.isFinal {
                    self.publisher.onCompleted()
                }
            }
        }
    }
    
    private let publisher = PublishSubject<State>.init()
    
    public let config: Config
    
    public let url: URL
    
    private var recorderWrapper: RecorderObserver! = nil
    
    private var bag = DisposeBag.init()
    
    public init(config: Config = Config.default, file: URL? = nil) {
        
        let fileExtension: String = config.format.proposedFileExtension
        
        self.config = config
        self.url = RecordSession.randomFileUrl(fileExtension: fileExtension)
    }
    
    public func subscribe() -> Observable<State> {
        return self.publisher.asObservable()
    }
    
    public func start() {
        guard self.state.isIdle else {
            return
        }
        
        self.state = .preparing
        
        self.prepare().observeOn(MainScheduler.instance).subscribe(onSuccess: { [weak self] (recorder) in
            self?.startRecording(recorder: recorder)
        }) { [weak self] (error) in
            self?.fail(error: error)
            }.disposed(by: self.bag)
    }
    
    public func cancel() {
        switch self.state {
        case .preparing:
            self.state = .cancelled
        case .recording(meters: _):
            self.state = .cancelled
            self.recorderWrapper!.recorder.stop()
            self.recorderWrapper.recorder.deleteRecording()
        default: break
        }
    }
    
    public func finish() {
        switch self.state {
        case .preparing:
            self.state = .cancelled
        case .recording(meters: _):
            self.recorderWrapper!.recorder.stop()
            self.state = .recorded
        default: break
        }
    }
    
    private func startRecording(recorder: AVAudioRecorder) {
        guard self.state.isPreparing else {
            return
        }
        
        let wrapper = RecorderObserver.init(recorder: recorder)
        self.recorderWrapper = wrapper
        
        self.state = .recording(meters: wrapper.currentMeters)
        wrapper.asObservable().observeOn(MainScheduler.asyncInstance).subscribe(onNext: { (meters) in
            self.state = .recording(meters: meters)
        }, onError: { (error) in
            self.fail(error: error)
        }, onCompleted: {
            self.state = .recorded
        }).disposed(by: self.bag)
        wrapper.recorder.record()
    }
    
    private func fail(error: Error?) {
        let targetError = error ?? AUDError.unknown
        self.state = .failed(targetError)
    }
    
    private func prepare() -> Single<AVAudioRecorder> {
        let config = self.config
        let url = self.url
        let settings = config.dictionaryRepresentation
        let recorder: AVAudioRecorder
        do {
            recorder = try AVAudioRecorder.init(url: url, settings: settings)
        }
        catch {
            return Single.error(error)
        }
        
        return Single.create { single in
            
            DispatchQueue.global(qos: .userInitiated).async {
                recorder.prepareToRecord()
                recorder.isMeteringEnabled = true
                single(.success(recorder))
            }
            
            return Disposables.create()
        }
    }
    
    class RecorderObserver: NSObject, AVAudioRecorderDelegate {
        
        typealias Meters = [Float]
        
        private let publisher = PublishSubject<Meters>.init()
        
        private var finished: Bool = false
        
        private var link: CADisplayLink!
        
        public let recorder: AVAudioRecorder
        
        private let channelsCount: Int
        
        init(recorder: AVAudioRecorder) {
            self.recorder = recorder
            self.channelsCount = (recorder.settings[AVNumberOfChannelsKey] as! NSNumber).intValue
            
            super.init()
            
            recorder.delegate = self
            self.link = CADisplayLink.init(target: self, selector: #selector(handleDisplayLinkFire))
            self.link.add(to: RunLoop.main, forMode: .commonModes)
        }
        
        func asObservable() -> Observable<Meters> {
            return self.publisher.asObservable()
        }
        
        @objc func handleDisplayLinkFire(_ link: CADisplayLink) {
            guard self.recorder.isRecording else {
                return
            }
            
            self.signalMeters()
        }
        
        public var currentMeters: Meters {
            self.recorder.updateMeters()
            var meters: [Float] = []
            for i in 0..<self.channelsCount {
                meters.append(self.recorder.averagePower(forChannel: i))
            }
            return meters
        }
        
        private func signalMeters() {
            self.publisher.onNext(self.currentMeters)
        }
        
        func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
            guard !finished else {
                return
            }
            self.finished = true
            self.publisher.onError(error ?? AUDError.undefinedRecordingError)
        }
        
        func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
            guard !finished else {
                if flag {
                    var sizeDescription: String = "unknown"
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: recorder.url.path),
                        let size = attributes[.size] as? Int64 {
                        sizeDescription = "\(size) b"
                    }
                    print("Recording finished, size: \(sizeDescription)")
                    self.publisher.onCompleted()
                }
                else {
                    print("Recording interrupted")
                    self.publisher.onError(AUDError.undefinedRecordingError)
                }
                return
            }
        }
    }
}
