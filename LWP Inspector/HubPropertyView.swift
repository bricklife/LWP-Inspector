import SwiftUI
import LWPKit

struct HubPropertyView: View {
    let hubProperty: HubProperty
    
    @EnvironmentObject var hub: Hub
    @State var text = ""
    
    var body: some View {
        Form {
            Section("Value") {
                Text(hub.hubProperties[hubProperty]?.description ?? "-")
            }
            
            Section("Supported Operations") {
                ForEach(hubProperty.operations, id: \.rawValue) { operation in
                    Text(operation.description)
                }
            }
            
            if hubProperty.operations.contains(where: { $0 == .enableUpdates || $0 == .disableUpdates || $0 == .requestUpdate }) {
                Section("Update Operations") {
                    if hubProperty.operations.contains(.enableUpdates) {
                        Button("Enable Updates") {
                            operate(.enableUpdates)
                        }
                    }
                    if hubProperty.operations.contains(.disableUpdates) {
                        Button("Disable Updates") {
                            operate(.disableUpdates)
                        }
                    }
                    if hubProperty.operations.contains(.requestUpdate) {
                        Button("Request Update") {
                            operate(.requestUpdate)
                        }
                    }
                }
            }
            
            if hubProperty.operations.contains(.set) {
                Section("Set Operation") {
                    TextField("Value", text: $text)
                    Button("Set") {
                        switch hubProperty.encoding {
                        case .string:
                            setValue(.string(text))
                        case .uint8:
                            if let value = UInt8(text) {
                                setValue(.uint8(value))
                            } else {
                                print("\(text) is not UInt8 value")
                            }
                        default:
                            print("Unsupported")
                        }
                    }
                }
            }
            
            if hubProperty.operations.contains(.reset) {
                Section("Reset Operation") {
                    Button("Reset") {
                        resetValue()
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(hubProperty.description)
    }
    
    func setValue(_ value: HubProperty.Value) {
        Task {
            do {
                try await hub.write(HubPropertyMessage(property: hubProperty, operation: .set, value: value))
                try await hub.write(HubPropertyMessage(property: hubProperty, operation: .requestUpdate))
                self.text = ""
            } catch {
                print("Error", error)
            }
        }
    }
    
    func resetValue() {
        Task {
            do {
                try await hub.write(HubPropertyMessage(property: hubProperty, operation: .reset))
                try await hub.write(HubPropertyMessage(property: hubProperty, operation: .requestUpdate))
            } catch {
                print("Error", error)
            }
        }
    }
    
    func operate(_ operation: HubProperty.Operation) {
        Task {
            do {
                try await hub.write(HubPropertyMessage(property: hubProperty, operation: operation))
            } catch {
                print("Error", error)
            }
        }
    }
}
