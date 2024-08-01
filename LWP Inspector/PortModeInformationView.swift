import SwiftUI
import LWPKit

struct PortModeInformationView: View {
    let portID: LWPKit.Port.ID
    let mode: UInt8
    
    @EnvironmentObject var hub: Hub
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text(String(format: "Port %d (0x%02x)", portID, portID))
                    Spacer()
                    Text(hub.attachedDevices[portID]?.description ?? "-")
                }
                HStack {
                    Text("Mode")
                    Spacer()
                    Text(mode.description)
                }
            }
            
            Section {
                let modeInformationTypes = ModeInformation.InformationType.allCases.filter({ $0 != .mapping && $0 != .valueFormat })
                ForEach(modeInformationTypes, id: \.rawValue) { modeInformationType in
                    HStack {
                        Text(modeInformationType.description)
                        Spacer()
                        let value = hub.modeInformationTypes[Key(portID: portID, mode: mode)]?[modeInformationType]
                        Text(value?.description ?? "-")
                    }
                }
            }
            
            Section("Mapping") {
                switch hub.modeInformationTypes[Key(portID: portID, mode: mode)]?[.mapping] {
                case .mapping(input: let input, output: let output):
                    HStack {
                        Text("Input")
                        Spacer()
                        Text(input.description)
                    }
                    HStack {
                        Text("Output")
                        Spacer()
                        Text(output.description)
                    }
                default:
                    EmptyView()
                }
            }
            
            Section("Value Format") {
                switch hub.modeInformationTypes[Key(portID: portID, mode: mode)]?[.valueFormat] {
                case .valueFormat(let valueFormat):
                    HStack {
                        Text("Number of Datasets")
                        Spacer()
                        Text(valueFormat.numberOfDatasets.description)
                    }
                    HStack {
                        Text("Dataset Type")
                        Spacer()
                        Text(valueFormat.datasetType.description)
                    }
                    HStack {
                        Text("Total Figures")
                        Spacer()
                        Text(valueFormat.totalFigures.description)
                    }
                    HStack {
                        Text("Decimals If Any")
                        Spacer()
                        Text(valueFormat.decimalsIfAny.description)
                    }
                default:
                    EmptyView()
                }
            }
            
            Section("Port Input Format Setup") {
                Button("Enable Notification") {
                    Task {
                        do {
                            let message = PortInputFormatSetupSingle(portID: portID, mode: mode, deltaInterval: 1, notificationEnabled: true)
                            try await hub.write(message)
                        } catch {
                            print("Error", error)
                        }
                    }
                }
                Button("Disable Notification") {
                    Task {
                        do {
                            let message = PortInputFormatSetupSingle(portID: portID, mode: mode, deltaInterval: 1, notificationEnabled: false)
                            try await hub.write(message)
                        } catch {
                            print("Error", error)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Port Mode Information")
        .task {
            do {
                try await hub.requestPortModeInformation(portID: portID, mode: mode)
            } catch {
                print("Error", error)
            }
        }
    }
}
