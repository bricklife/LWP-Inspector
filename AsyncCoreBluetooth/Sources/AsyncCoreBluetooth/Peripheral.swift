//
//  Peripheral.swift
//  AsyncCoreBluetooth
//
//  Created by Shinichiro Oba on 2024/02/27.
//

import CoreBluetooth

@BLEActor
public final class Service {
    let cbService: CBService
    
    nonisolated public let uuid: BLEUUID
    
    public var characteristics: [Characteristic] {
        cbService.characteristics?.map { Characteristic(cbCharacteristic: $0) } ?? []
    }
    
    public init(cbService: CBService) {
        self.cbService = cbService
        self.uuid = BLEUUID(cbuuid: cbService.uuid)
    }
}

@BLEActor
public final class Characteristic {
    let cbCharacteristic: CBCharacteristic
    
    nonisolated public let uuid: BLEUUID
    
    public init(cbCharacteristic: CBCharacteristic) {
        self.cbCharacteristic = cbCharacteristic
        self.uuid = BLEUUID(cbuuid: cbCharacteristic.uuid)
    }
}

@BLEActor
fileprivate final class Context {
    fileprivate var discoverServicesContinuation: CheckedContinuation<Void, any Error>?
    fileprivate var discoverCharacteristicsContinuations: [BLEUUID : CheckedContinuation<Void, any Error>] = [:]
    
    fileprivate var notificationContinuations: [BLEUUID : AsyncStream<Data>.Continuation] = [:]
}

@BLEActor
fileprivate class DelegateWrapper: NSObject {
    private let context: Context
    
    init(context: Context) {
        self.context = context
    }
}

@BLEActor
public final class Peripheral {
    let cbPeripheral: CBPeripheral
    
    nonisolated public let identifier: UUID
    
    public var name: String? {
        cbPeripheral.name
    }
    
    public var services: [Service] {
        cbPeripheral.services?.map { Service(cbService: $0) } ?? []
    }
    
    fileprivate let context = Context()
    fileprivate let delegateWrapper: DelegateWrapper
    
    public init(cbPeripheral: CBPeripheral) {
        self.cbPeripheral = cbPeripheral
        self.identifier = cbPeripheral.identifier
        self.delegateWrapper = DelegateWrapper(context: self.context)
        cbPeripheral.delegate = delegateWrapper
    }
    
    @discardableResult
    public func discoverServices(uuids: [BLEUUID]? = nil) async throws -> [Service] {
        if let uuids, uuids.allSatisfy({ services.map(\.uuid).contains($0) }) {
            return services.filter { uuids.contains($0.uuid) }
        }
        
        try await withCheckedThrowingContinuation { continuation in
            Task { @BLEActor in
                context.discoverServicesContinuation = continuation
                cbPeripheral.discoverServices(uuids?.map(\.cbuuid))
            }
        }
        if let uuids {
            return services.filter { uuids.contains($0.uuid) }
        } else {
            return services
        }
    }
    
    @discardableResult
    public func discoverCharacteristics(uuids: [BLEUUID]? = nil, for service: Service) async throws -> [Characteristic] {
        if let uuids, uuids.allSatisfy({ service.characteristics.map(\.uuid).contains($0) }) {
            return service.characteristics.filter { uuids.contains($0.uuid) }
        }
        
        try await withCheckedThrowingContinuation { continuation in
            Task { @BLEActor in
                context.discoverCharacteristicsContinuations[service.uuid] = continuation
                cbPeripheral.discoverCharacteristics(uuids?.map(\.cbuuid), for: service.cbService)
            }
        }
        if let uuids {
            return service.characteristics.filter { uuids.contains($0.uuid) }
        } else {
            return service.characteristics
        }
    }
    
    public func startNotification(for characteristic: Characteristic) -> AsyncStream<Data> {
        return AsyncStream<Data> { continuation in
            context.notificationContinuations[characteristic.uuid] = continuation
            cbPeripheral.setNotifyValue(true, for: characteristic.cbCharacteristic)
        }
    }
    
    public func stopNotification(for characteristic: Characteristic) {
        context.notificationContinuations[characteristic.uuid] = nil
        cbPeripheral.setNotifyValue(false, for: characteristic.cbCharacteristic)
    }
    
    public func writeWithoutResponse(data: Data, characteristic: Characteristic) {
        cbPeripheral.writeValue(data, for: characteristic.cbCharacteristic, type: .withoutResponse)
    }
}

extension Peripheral {
    @discardableResult
    public func discoverService(uuid: BLEUUID) async throws -> Service {
        guard let service = try await discoverServices(uuids: [uuid]).first else {
            throw Error.serviceNotFound
        }
        return service
    }
    
    @discardableResult
    public func discoverCharacteristic(uuid: BLEUUID, for service: Service) async throws -> Characteristic {
        guard let characteristic = try await discoverCharacteristics(uuids: [uuid], for: service).first else {
            throw Error.characteristicNotFound
        }
        return characteristic
    }
    
    public func discoverAllServicesAndCharacteristics() async throws {
        let services = try await discoverServices()
        await withThrowingTaskGroup(of: Void.self) { group in
            for service in services {
                group.addTask { @BLEActor in
                    try await self.discoverCharacteristics(for: service)
                }
            }
        }
    }
}

extension DelegateWrapper: CBPeripheralDelegate {
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        print(#function, peripheral.services?.map(\.uuid) ?? "[]")
        Task { @BLEActor in
            context.discoverServicesContinuation?.resume(with: error.map { .failure($0) } ?? .success(()))
            context.discoverServicesContinuation = nil
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        print(#function, service.characteristics?.map(\.uuid) ?? "[]")
        let uuid = BLEUUID(cbuuid: service.uuid)
        Task { @BLEActor in
            context.discoverCharacteristicsContinuations[uuid]?.resume(with: error.map { .failure($0) } ?? .success(()))
            context.discoverCharacteristicsContinuations[uuid] = nil
        }
    }
    
    nonisolated func peripheral(_ cbPeripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        let uuid = BLEUUID(cbuuid: characteristic.uuid)
        if let data = characteristic.value {
            Task { @BLEActor in
                _ = context.notificationContinuations[uuid]?.yield(data)
            }
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: (any Error)?) {
        print(#function, characteristic, error ?? "")
    }
}

extension Peripheral {
    public enum Error: Swift.Error {
        case serviceNotFound
        case characteristicNotFound
    }
}
