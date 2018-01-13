//
//  UserDefaults+AudD.swift
//  AudD
//
//  Created by Aleksei Gordeev on 13/01/2018.
//  Copyright © 2018 Dialog. All rights reserved.
//

import Foundation

public extension UserDefaults {
    
    private static let auddUserIdKey = "com.vladlex.AudD.userId"
    var auddUserId: String {
        get {
            if let value = self.string(forKey: UserDefaults.auddUserIdKey) {
                return value
            }
            else {
                let value = UUID().uuidString
                self.auddUserId = value
                return value
            }
        }
        
        set {
            self.set(newValue, forKey: UserDefaults.auddUserIdKey)
        }
    }
}

