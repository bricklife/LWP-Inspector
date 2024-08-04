import SwiftUI
import LWPKit

struct PortView: View {
    let portID: LWPKit.Port.ID
    let ioType: Defined<IOType>
    
    @EnvironmentObject var hub: Hub
    @State var power: Int8 = 0
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text(String(format: "Port %d (0x%02x)", portID, portID))
                    Spacer()
                    Text(hub.attachedDevices[portID]?.description ?? "-")
                }
            }
            
            Section("Mode Info") {
                HStack {
                    Text("Capabilities")
                    Spacer()
                    Text(hub.modeInfos[portID]?.capabilities.description ?? "-")
                }
                HStack {
                    Text("Total Mode Count")
                    Spacer()
                    Text(hub.modeInfos[portID]?.totalModeCount.description ?? "-")
                }
                HStack {
                    Text("Input Modes")
                    Spacer()
                    Text(hub.modeInfos[portID]?.inputModes.description ?? "-")
                }
                HStack {
                    Text("Output Modes")
                    Spacer()
                    Text(hub.modeInfos[portID]?.outputModes.description ?? "-")
                }
            }
            
            Section("Possible Mode Combinations") {
                if let combinations = hub.possibleModeCombinations[portID], !combinations.isEmpty {
                    ForEach(combinations, id: \.rawValue) { portModeSet in
                        Text(portModeSet.description)
                    }
                } else {
                    Text("None")
                }
            }
            
            Section("Port Mode Information") {
                if let totalModeCount = hub.modeInfos[portID]?.totalModeCount, totalModeCount > 0 {
                    ForEach(0..<totalModeCount, id: \.self) { mode in
                        NavigationLink(mode.description) {
                            PortModeInformationView(portID: portID, mode: mode)
                                .environmentObject(hub)
                        }
                    }
                }
            }
            
            if StartPower.canUse(for: ioType) {
                Section("Power Control") {
                    Stepper {
                        Text("Power: \(power)")
                    } onIncrement: {
                        power = min(power + 10, 100)
                        setPower(power)
                    } onDecrement: {
                        power = max(power - 10, -100)
                        setPower(power)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Port Information")
        .onAppear {
            requestPortInformation()
        }
        .onDisappear {
            if StartPower.canUse(for: ioType) {
                setPower(0)
            }
        }
    }
    
    func requestPortInformation() {
        Task {
            do {
                try await hub.requestPortInformation(portID: portID)
            } catch {
                print("Error", error)
            }
        }
    }
    
    func setPower(_ power: Int8) {
        Task {
            do {
                try await hub.write(StartPower(portID: portID, power: power))
            } catch {
                print("Error:", error)
            }
        }
    }
}
