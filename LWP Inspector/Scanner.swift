import Combine
import Foundation
import AsyncCoreBluetooth
import LWPKit
import OrderedCollections

@MainActor
class Scanner: ObservableObject {
    @Published var isScanning = false
    @Published var discoveredPeripherals: OrderedDictionary<UUID, DiscoveredPeripheral> = [:]
    
    func startScan() {
        Task {
            do {
                print("Scan start")
                isScanning = true
                discoveredPeripherals = [:]
                try await CentralManager.shared.waitUntilReady()
                for try await p in await CentralManager.shared.startScan(serviceUuids: [serviceUuid]) {
                    if let manufacturerData = p.manufacturerData.flatMap(ManufacturerData.init(data:)) {
                        print("Found:", p.name ?? "Unknown", "<\(manufacturerData)>")
                        discoveredPeripherals[p.identifier] = p
                    }
                }
                isScanning = false
                print("Scan done")
            } catch {
                print("Error:", self, error)
                isScanning = false
            }
        }
    }
    
    func stopScan() {
        Task {
            await CentralManager.shared.stopScan()
        }
    }
}
