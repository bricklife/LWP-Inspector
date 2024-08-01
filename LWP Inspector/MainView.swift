import SwiftUI
import LWPKit

struct MainView: View {
    let uuid: UUID
    
    @StateObject var hub = Hub()
    
    let hubProperties: [HubProperty] = [
        .advertisingName,
        .firmwareVersion,
        .batteryVoltage,
    ]
    
    var body: some View {
        Form {
            Section("Hub Properties") {
                ForEach(hubProperties, id: \.self) { hubProperty in
                    HStack {
                        Text(hubProperty.description)
                        Spacer()
                        Text(hub.hubProperties[hubProperty]?.description ?? "-")
                    }
                }
                NavigationLink("View All") {
                    HubPropertyListView()
                        .environmentObject(hub)
                }
            }
            
            Section("Attached I/O") {
                ForEach(hub.attachedDevices.sorted(by: { $0.key < $1.key }), id: \.key) { (portID, ioType) in
                    NavigationLink {
                        PortView(portID: portID, ioType: ioType)
                            .environmentObject(hub)
                    } label: {
                        HStack {
                            Text(String(format: "Port %d (0x%02x)", portID, portID))
                            Spacer()
                            Text(hub.attachedDevices[portID]?.description ?? "-")
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(hub.hubProperties[.advertisingName]?.description ?? "")
        .toolbar {
            Button("Disconnect") {
                Task {
                    await hub.disconnect()
                }
            }
        }
        .onAppear {
            Task {
                if !hub.isConnected {
                    await hub.connect(uuid: uuid)
                }
                do {
                    try await hub.disableAllUpdates()
                    try await hub.write(HubPropertyMessage(property: .batteryVoltage, operation: .enableUpdates))
                } catch {
                    print("Error:", error)
                }
            }
        }
    }
}
