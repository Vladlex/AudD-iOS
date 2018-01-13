//
//  RecordPanel.swift
//  AudD
//
//  Created by Aleksei Gordeev on 13/01/2018.
//  Copyright © 2018 Dialog. All rights reserved.
//

import UIKit
import RxSwift

public class RecordPanel: UIView {
    
    public typealias E = Event
    
    private let publisher = PublishSubject<Event>.init()
    private let bag = DisposeBag.init()
    
    public func asObserver() -> Observable<Event> {
        return self.publisher.asObserver()
    }
    
    public struct Event {
        public var target: Target
        public var subevent: Subevent
        
        public enum Target {
            case ambient
            case voice
        }
        
        public enum Subevent {
            case begin
            case cancelled
            case finished
        }
    }
    
    private var ambientButton: UIButton!
    private var voiceButton: UIButton!
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.onAfterInit(isFromDecoder: false)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.onAfterInit(isFromDecoder: true)
    }
    
    private var isResettingTracker: Bool = false
    public func resetTracking() {
        self.isResettingTracker = true
        
        self.ambientButton.isEnabled = false
        self.ambientButton.isEnabled = true
        
        self.voiceButton.isEnabled = false
        self.voiceButton.isEnabled = true
        self.isResettingTracker = false
    }
    
    private func onAfterInit(isFromDecoder: Bool) {
        
        self.ambientButton = UIButton(type: .system)
        self.voiceButton = UIButton(type: .system)
        
        if !isFromDecoder {
            self.isMultipleTouchEnabled = false
        }
        
        self.ambientButton.setTitle("Ambient", for: .normal)
        self.voiceButton.setTitle("Voice", for: .normal)
        
        self.addSubview(ambientButton)
        self.addSubview(voiceButton)
        
        self.beginTrackButton(self.ambientButton)
        self.beginTrackButton(self.voiceButton)
    }
    
    private func lockTarget(_ target: Event.Target) {
        switch target {
        case .ambient: self.voiceButton.isEnabled = false
        case .voice: self.ambientButton.isEnabled = false
        }
    }
    
    private func unlockTarget(_ target: Event.Target) {
        switch target {
        case .ambient: self.voiceButton.isEnabled = true
        case .voice: self.ambientButton.isEnabled = true
        }
    }
    
    private func beginTrackButton(_ button: UIButton) {
        let target: Event.Target
        if button === self.ambientButton {
            target = .ambient
        }
        else if button === self.voiceButton {
            target = .voice
        }
        else {
            return
        }
        
        button.rx.controlEvent(.touchDown).subscribe { _ in
            self.lockTarget(target)
            
            let event = Event.init(target: target, subevent: .begin)
            self.publisher.onNext(event)
            }.disposed(by: self.bag)
        
        button.rx.controlEvent(.touchCancel).subscribe { _ in
            self.unlockTarget(target)
            
            let event = Event.init(target: target, subevent: .cancelled)
            self.publisher.onNext(event)
            }.disposed(by: self.bag)
        
        button.rx.controlEvent(.touchUpOutside).subscribe { _ in
            self.unlockTarget(target)
            
            let event = Event.init(target: target, subevent: .cancelled)
            self.publisher.onNext(event)
            }.disposed(by: self.bag)
        
        button.rx.controlEvent(.touchUpInside).subscribe { _ in
            self.unlockTarget(target)
            
            let event = Event.init(target: target, subevent: .finished)
            self.publisher.onNext(event)
            }.disposed(by: self.bag)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        let templateRect = CGRect.init(x: 0.0,
                                       y: 0.0,
                                       width: self.bounds.size.width / 2.0,
                                       height: self.bounds.size.height)
        self.ambientButton.frame = templateRect
        
        var voiceRect = templateRect
        voiceRect.origin.x = templateRect.size.width
        self.voiceButton.frame = voiceRect
    }
    
}

