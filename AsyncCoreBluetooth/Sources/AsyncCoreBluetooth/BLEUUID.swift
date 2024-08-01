//
//  BLEUUID.swift
//  AsyncCoreBluetooth
//
//  Created by Shinichiro Oba on 2024/02/27.
//

import CoreBluetooth

public struct BLEUUID: Hashable, Sendable {
    public let uuidString: String
    
    public init(string: String) {
        self.uuidString = string.uppercased()
    }
    
    var cbuuid: CBUUID {
        CBUUID(string: uuidString)
    }
    
    init(cbuuid: CBUUID) {
        self.uuidString = cbuuid.uuidString.uppercased()
    }
}
