import Combine
import Foundation
import AsyncCoreBluetooth
import LWPKit

struct Key: Hashable {
    let portID: LWPKit.Port.ID
    let mode: UInt8
}

@MainActor
class Hub: ObservableObject {
    @Published var isConnected = false
    @Published var hubProperties: [HubProperty : HubProperty.Value] = [:]
    @Published var attachedDevices: [UInt8 : Defined<IOType>] = [:]
    @Published var modeInfos: [UInt8 : PortInformation.ModeInfo] = [:]
    @Published var possibleModeCombinations: [UInt8 : PortInformation.PossibleModeCombinations] = [:]
    @Published var modeInformationTypes: [Key : [ModeInformation.InformationType : ModeInformation.Value]] = [:]
    
    private var peripheral: Peripheral?
    private var characteristic: Characteristic?
    
    private var nofityTask: Task<(), Never>?
    
    private let byteParser = ByteParser<Data>()
    private var tasks: Set<Task<(), Never>> = []
    
    init() {
        setupByteParser()
    }
    
    func setupByteParser() {
        tasks.insert(Task {
            for await message in await byteParser.messageStream(for: HubAttachedIOMessage.self) {
                print(">>", message)
                switch message.event {
                case .detachedIO:
                    attachedDevices[message.portID] = nil
                case .attachedIO(ioTypeID: let ioTypeID, hardwareRevision: _, softwareRevision: _):
                    attachedDevices[message.portID] = .init(id: ioTypeID)
                case .attachedVirtualIO(ioTypeID: let ioTypeID, firstPortID: _, secondPortID: _):
                    attachedDevices[message.portID] = .init(id: ioTypeID)
                }
            }
        })
        
        tasks.insert(Task {
            for await message in await byteParser.messageStream(for: HubPropertyMessage.self) {
                print(">>", message)
                hubProperties[message.property] = message.value
            }
        })
        
        tasks.insert(Task {
            for await message in await byteParser.messageStream(for: ErrorMessage.self) {
                print(">>", message)
            }
        })
        
        tasks.insert(Task {
            for await message in await byteParser.messageStream(for: PortInformation.self) {
                print(">>", message)
                switch message.information {
                case .modeInfo(let value):
                    modeInfos[message.portID] = value
                case .possibleModeCombinations(let value):
                    possibleModeCombinations[message.portID] = value
                }
            }
        })
        
        tasks.insert(Task {
            for await message in await byteParser.messageStream(for: PortModeInformation.self) {
                print(">>", message)
                let key = Key(portID: message.portID, mode: message.mode)
                modeInformationTypes[key]?[message.type] = message.value
            }
        })
        
        tasks.insert(Task {
            for await message in await byteParser.messageStream(for: PortInputFormatSingle.self) {
                print(">>", message)
            }
        })
        
        tasks.insert(Task {
            for await message in await byteParser.messageStream(for: PortValueSingle.self) {
                print(">>", message)
            }
        })
    }
    
    func connect(uuid: UUID) async {
        guard peripheral == nil else { return }
        do {
            let peripheral = try await CentralManager.shared.peripheral(from: uuid)
            try await CentralManager.shared.connect(peripheral: peripheral)
            
            print("Connected")
            
            let service = try await peripheral.discoverService(uuid: serviceUuid)
            let characteristic = try await peripheral.discoverCharacteristic(uuid: characteristicUuid, for: service)
            
            nofityTask = Task {
                for await data in await peripheral.startNotification(for: characteristic) {
                    await byteParser.parse(data)
                }
            }
            
            self.characteristic = characteristic
            self.peripheral = peripheral
            self.isConnected = true
            
            Task {
                for property in HubProperty.allCases {
                    try await write(HubPropertyMessage(property: property, operation: .requestUpdate))
                }
            }
            
            print("Ready!")
            
        } catch {
            print("Error:", error)
            self.nofityTask?.cancel()
            self.nofityTask = nil
            if let peripheral {
                try? await CentralManager.shared.disconnect(peripheral: peripheral)
            }
            for task in self.tasks {
                task.cancel()
            }
            self.characteristic = nil
            self.peripheral = nil
        }
    }
    
    func disconnect() async {
        guard let peripheral else { return }
        do {
            self.nofityTask?.cancel()
            self.nofityTask = nil
            for task in self.tasks {
                task.cancel()
            }
            try await CentralManager.shared.disconnect(peripheral: peripheral)
            self.characteristic = nil
            self.peripheral = nil
        } catch {
            print("Error:", error)
        }
    }
    
    func write(_ message: EncodableMessage) async throws {
        guard let characteristic else { return }
        print("<<", message)
        let data = try message.data()
        print("  ", "[", data.hexString, "]")
        await peripheral?.writeWithoutResponse(data: data, characteristic: characteristic)
    }
    
    func enableAllUpdates() async throws {
        let properties = HubProperty.allCases.filter { $0.operations.contains(.enableUpdates) }
        for property in properties {
            try await write(HubPropertyMessage(property: property, operation: .enableUpdates))
        }
    }
    
    func disableAllUpdates() async throws {
        let properties = HubProperty.allCases.filter { $0.operations.contains(.disableUpdates) }
        for property in properties {
            try await write(HubPropertyMessage(property: property, operation: .disableUpdates))
        }
    }
    
    func setHubLEDColor(_ color: Color) async throws {
        for (portID, ioType) in attachedDevices {
            if SetRgbColorNo.canUse(for: ioType) {
                try await write(SetRgbColorNo(portID: portID, color: color))
            }
        }
    }
    
    func startMotor(power: Int8) async throws {
        for (portID, ioType) in attachedDevices {
            if StartPower.canUse(for: ioType) {
                try await write(StartPower(portID: portID, power: power))
            }
        }
    }
    
    func startMotor(speed: Int8) async throws {
        for (portID, ioType) in attachedDevices {
            if StartSpeed.canUse(for: ioType) {
                try await write(StartSpeed(portID: portID, speed: speed, maxPower: 100))
            }
        }
    }
    
    func requestPortInformation(portID: LWPKit.Port.ID) async throws {
        self.modeInfos[portID] = nil
        self.possibleModeCombinations[portID] = nil
        for informationType in PortInformationRequest.InformationType.allCases {
            try await write(PortInformationRequest(portID: portID, informationType: informationType))
        }
    }
    
    func requestPortModeInformation(portID: LWPKit.Port.ID, mode: UInt8) async throws {
        self.modeInformationTypes[Key(portID: portID, mode: mode)] = [:]
        for modeInformationType in ModeInformation.InformationType.allCases {
            try await write(PortModeInformationRequest(portID: portID, mode: mode, modeInformationType: modeInformationType))
        }
    }
}

extension PortOutputCommand {
    static func canUse(for ioType: Defined<IOType>) -> Bool {
        switch ioType {
        case .defined(let ioType):
            return canUse(for: ioType)
        case .undefined:
            return false
        }
    }
}
