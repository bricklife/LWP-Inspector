//
//  BLEActor.swift
//  AsyncCoreBluetooth
//
//  Created by Shinichiro Oba on 2024/02/27.
//

@globalActor
public struct BLEActor {
    public actor ActorType { }
    
    public static let shared: ActorType = ActorType()
}
