//
//  Item.swift
//  LiveBuddy
//
//  Created by Huy Huỳnh on 11/6/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
