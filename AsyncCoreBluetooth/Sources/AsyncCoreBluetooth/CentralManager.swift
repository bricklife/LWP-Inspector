//
//  CentralManager.swift
//  AsyncCoreBluetooth
//
//  Created by Shinichiro Oba on 2024/02/27.
//

import CoreBluetooth

public struct DiscoveredPeripheral: Sendable {
    public let identifier: UUID
    public let name: String?
    public let manufacturerData: Data?
    public let rssi: Int
}

@BLEActor
fileprivate final class Context {
    fileprivate var isReadyContinuation: CheckedContinuation<Void, any Error>?
    fileprivate var scanStreamContinuation: AsyncThrowingStream<DiscoveredPeripheral, any Error>.Continuation?
    fileprivate var connectContinuations: [UUID : CheckedContinuation<Void, any Error>] = [:]
    fileprivate var disconnectContinuations: [UUID : CheckedContinuation<Void, any Error>] = [:]
}

@BLEActor
fileprivate class DelegateWrapper: NSObject {
    private let context: Context
    
    init(context: Context) {
        self.context = context
    }
}

@BLEActor
public final class CentralManager {
    public static let shared = CentralManager()
    
    private let queue = DispatchQueue(label: "AsyncCoreBluetooth.CentralManager.queue")
    
    lazy var centralManager: CBCentralManager = {
        CBCentralManager(delegate: delegateWrapper, queue: queue)
    }()
    
    fileprivate let context = Context()
    fileprivate let delegateWrapper: DelegateWrapper
    
    public init() {
        self.delegateWrapper = DelegateWrapper(context: self.context)
    }
    
    public func getReady() {
        _ = centralManager
    }
    
    public func waitUntilReady() async throws {
        print(centralManager.state)
        switch centralManager.state {
        case .poweredOn:
            return
        case .unauthorized, .poweredOff, .unsupported:
            throw Error.cannotUse(reason: centralManager.state)
        default:
            try await withCheckedThrowingContinuation { continuation in
                context.isReadyContinuation = continuation
            }
        }
    }
    
    public func startScan(serviceUuids: [BLEUUID]? = nil) -> AsyncThrowingStream<DiscoveredPeripheral, any Swift.Error> {
        if centralManager.isScanning {
            // 再スキャンするために一回停止
            stopScan()
        }
        
        return AsyncThrowingStream { continuation in
            continuation.onTermination = { @Sendable t in
                print("scanStreamContinuation", t)
            }
            context.scanStreamContinuation = continuation
            let uuids = serviceUuids?.compactMap { $0.cbuuid }
            centralManager.scanForPeripherals(withServices: uuids)
        }
    }
    
    public func stopScan() {
        centralManager.stopScan()
        context.scanStreamContinuation?.finish()
        context.scanStreamContinuation = nil
    }
    
    public func connect(peripheral: Peripheral) async throws {
        try await connect(cbPeripheral: peripheral.cbPeripheral)
    }
    
    public func connect(with identifier: UUID) async throws {
        try await connect(cbPeripheral: cbPeripheral(from: identifier))
    }
    
    private func connect(cbPeripheral: CBPeripheral) async throws {
        guard cbPeripheral.state == .disconnected else { return }
        try await withCheckedThrowingContinuation { continuation in
            Task { @BLEActor in
                context.connectContinuations[cbPeripheral.identifier] = continuation
                centralManager.connect(cbPeripheral, options: nil)
            }
        }
    }
    
    public func disconnect(peripheral: Peripheral) async throws {
        try await disconnect(cbPeripheral: peripheral.cbPeripheral)
    }
    
    public func disconnect(with identifier: UUID) async throws {
        try await disconnect(cbPeripheral: cbPeripheral(from: identifier))
    }
    
    private func disconnect(cbPeripheral: CBPeripheral) async throws {
        guard cbPeripheral.state == .connected else { return }
        try await withCheckedThrowingContinuation { continuation in
            Task { @BLEActor in
                context.disconnectContinuations[cbPeripheral.identifier] = continuation
                centralManager.cancelPeripheralConnection(cbPeripheral)
            }
        }
    }
    
    public func peripheral(from discoveredPeripheral: DiscoveredPeripheral) throws -> Peripheral {
        return try peripheral(from: discoveredPeripheral.identifier)
    }
    
    public func peripheral(from identifier: UUID) throws -> Peripheral {
        return try Peripheral(cbPeripheral: cbPeripheral(from: identifier))
    }
    
    private func cbPeripheral(from identifier: UUID) throws -> CBPeripheral {
        guard let cbPeripheral = centralManager.retrievePeripherals(withIdentifiers: [identifier]).first else {
            throw Error.unknownPeripheral
        }
        return cbPeripheral
    }
}

extension DelegateWrapper: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print(#function, central.state)
        let state = central.state
        Task { @BLEActor in
            if state == .poweredOn {
                context.isReadyContinuation?.resume()
                context.isReadyContinuation = nil
            } else {
                context.isReadyContinuation?.resume(throwing: CentralManager.Error.cannotUse(reason: state))
                context.isReadyContinuation = nil
                context.scanStreamContinuation?.finish(throwing: CentralManager.Error.stopped(reason: state))
                context.scanStreamContinuation = nil
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        
        let discoveredPeripheral = DiscoveredPeripheral(identifier: peripheral.identifier,
                                                        name: localName ?? peripheral.name,
                                                        manufacturerData: manufacturerData,
                                                        rssi: RSSI.intValue)
        Task { @BLEActor in
            _ = context.scanStreamContinuation?.yield(discoveredPeripheral)
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let identifier = peripheral.identifier
        Task { @BLEActor in
            context.connectContinuations[identifier]?.resume()
            context.connectContinuations[identifier] = nil
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        let identifier = peripheral.identifier
        Task { @BLEActor in
            context.connectContinuations[identifier]?.resume(throwing: error ?? CentralManager.Error.unknown)
            context.connectContinuations[identifier] = nil
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        let identifier = peripheral.identifier
        Task { @BLEActor in
            context.disconnectContinuations[identifier]?.resume(with: error.map { .failure($0) } ?? .success(()))
            context.disconnectContinuations[identifier] = nil
        }
    }
}

extension CentralManager {
    public enum Error: Swift.Error {
        case cannotUse(reason: CBManagerState)
        case stopped(reason: CBManagerState)
        case unknownPeripheral
        case unknown
    }
}

extension CBManagerState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unknown:
            return "unknown"
        case .resetting:
            return "resetting"
        case .unsupported:
            return "unsupported"
        case .unauthorized:
            return "unauthorized"
        case .poweredOff:
            return "poweredOff"
        case .poweredOn:
            return "poweredOn"
        @unknown default:
            return "@unknown default"
        }
    }
}
