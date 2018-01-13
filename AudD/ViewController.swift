//
//  ViewController.swift
//  AudD
//
//  Created by Aleksei Gordeev on 13/01/2018.
//  Copyright © 2018 Dialog. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet public private(set) var recordPanelContainer: UIView!
    
    private var recordController: RecordViewController!
    
    private let bag = DisposeBag.init()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupRecordController()
    }
    
    private func setupRecordController() {
        let controller = RecordViewController.init(nibName: nil, bundle: nil)
        controller.view.frame = self.recordPanelContainer.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        self.recordPanelContainer.addSubview(controller.view)
        self.addChildViewController(controller)
        self.recordController = controller
        
        var config = RecordSession.Config.default
        config.format = .wav
        controller.recordingConfig = config
        
        controller.asObserver().subscribe(onNext: { [weak self] (event) in
            switch event {
            case .failRecording(error: let error):
                let alert = UIAlertController.init(title: "Error",
                                                   message: error.localizedDescription,
                                                   preferredStyle: .alert)
                alert.addAction(UIAlertAction.init(title: "ok", style: .default, handler: nil))
                self?.present(alert, animated: true, completion: nil)
            default: break
            }
        }).disposed(by: self.bag)
    }

}

