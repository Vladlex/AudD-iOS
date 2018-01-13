//
//  RecordViewController.swift
//  AudD
//
//  Created by Aleksei Gordeev on 13/01/2018.
//  Copyright © 2018 Dialog. All rights reserved.
//

import UIKit
import RxSwift

public class RecordViewController: UIViewController {
    
    public enum Event {
        case currentRecordChanged(url: URL)
        case failRecording(error: Error)
    }
    
    private let publisher = PublishSubject<Event>.init()
    
    public var recordingConfig: RecordSession.Config = .default
    
    public private(set) var recordPanel: RecordPanel!
    
    public func asObserver() -> Observable<Event> {
        return self.publisher.asObserver()
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupPanel()
        
        RecordSession.removeOldRecords()
        self.recordPanel.asObserver().subscribe(onNext: { [unowned self] (event) in
            switch event.subevent {
            case .begin:
                self.beginSession()
            case .cancelled:
                self.cancelSession()
            case .finished:
                self.finishSession()
            }
        }).disposed(by: self.bag)
    }
    
    private var recordSession: RecordSession! = nil
    
    private var bag = DisposeBag.init()
    private var sessionsBag = DisposeBag.init()
    
    private let fileSizeFormatter = ByteCountFormatter.init()
    
    private func setupPanel() {
        self.recordPanel = RecordPanel.init(frame: self.view.bounds)
        self.recordPanel.translatesAutoresizingMaskIntoConstraints = false
        
        self.view.addSubview(self.recordPanel)
        
        let constraints: [NSLayoutConstraint]
        if #available(iOS 11, *) {
            let area = self.view.safeAreaLayoutGuide
            constraints = [
                area.topAnchor.constraintEqualToSystemSpacingBelow(self.recordPanel.topAnchor, multiplier: 1.0),
                area.leadingAnchor.constraintEqualToSystemSpacingAfter(self.recordPanel.leadingAnchor, multiplier: 1.0),
                self.recordPanel.trailingAnchor.constraintEqualToSystemSpacingAfter(area.trailingAnchor, multiplier: 1.0),
                self.recordPanel.bottomAnchor.constraintEqualToSystemSpacingBelow(area.bottomAnchor, multiplier: 1.0)
            ]
        }
        else {
            constraints = [
                self.topLayoutGuide.bottomAnchor.constraintEqualToSystemSpacingBelow(self.recordPanel.topAnchor,
                                                                                     multiplier: 1.0),
                self.view.leadingAnchor.constraintEqualToSystemSpacingAfter(self.recordPanel.leadingAnchor,
                                                                            multiplier: 1.0),
                self.recordPanel.trailingAnchor.constraintEqualToSystemSpacingAfter(self.view.trailingAnchor,
                                                                             multiplier: 1.0),
                self.recordPanel.bottomAnchor.constraintEqualToSystemSpacingBelow(self.view.bottomAnchor,
                                                                                  multiplier: 1.0)
            ]
        }
        NSLayoutConstraint.activate(constraints)
    }
    
    private func handleSessionRecordingFailure(_ error: Error) {
        self.recordPanel.resetTracking()
        self.publisher.onNext(.failRecording(error: error))
    }
    
    private func handleRecordCompleted() {
        
    }
    
    private func updateMeterUi(_ meters: [Float]) {
        // No meter UI right now
    }
    
    private func beginSession() {
        
        let session = RecordSession.init(config: self.recordingConfig)
        
        session.subscribe().observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] (state) in
            switch state {
            case .recording(meters: let meters): self?.updateMeterUi(meters)
            default: break
            }
            }, onError: { [weak self] (error) in
                self?.handleSessionRecordingFailure(error)
            }, onCompleted: { [weak self] in
                self?.handleRecordCompleted()
        }).disposed(by: self.sessionsBag)
        self.recordSession = session
        session.start()
    }
    
    private func cancelSession() {
        if let session = self.recordSession {
            session.cancel()
        }
        self.sessionsBag = DisposeBag.init()
    }
    
    private func finishSession() {
        if let session = self.recordSession {
            session.finish()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                let path = session.url.path
                if !FileManager.default.fileExists(atPath: path) {
                    print("file \(path) does not exist!")
                }
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: session.url.path)
                    if let size = attributes[.size] {
                        let descr = self.fileSizeFormatter.string(fromByteCount: size as! Int64)
                        print("Record (\(descr)): \(session.url.path)")
                    }
                }
                catch {
                    let fileExists = FileManager.default.fileExists(atPath: path)
                    print("Fail to detect attributes of \(path). Exists: \(fileExists). \(error)")
                }
                
                if let attributes = try? FileManager.default.attributesOfItem(atPath: session.url.path),
                    let size = attributes[.size] {
                    let descr = self.fileSizeFormatter.string(fromByteCount: size as! Int64)
                    print("Record (\(descr)): \(session.url.path)")
                }
            })
            
            
            
        }
        
        self.sessionsBag = DisposeBag.init()
    }

}

