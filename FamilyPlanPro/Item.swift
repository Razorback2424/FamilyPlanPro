//
//  Item.swift
//  FamilyPlanPro
//
//  Created by Sean Keller on 6/25/25.
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
