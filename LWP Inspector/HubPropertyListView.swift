import SwiftUI
import LWPKit

struct HubPropertyListView: View {
    @EnvironmentObject var hub: Hub
    
    var body: some View {
        Form {
            Section {
                ForEach(HubProperty.allCases, id: \.self) { hubProperty in
                    NavigationLink {
                        HubPropertyView(hubProperty: hubProperty)
                            .environmentObject(hub)
                    } label: {
                        HStack {
                            Text(hubProperty.description)
                            Spacer()
                            Text(hub.hubProperties[hubProperty]?.description ?? "-")
                        }
                    }
                }
            }
            
            Section {
                Button("Enable All Updates") {
                    enableAllUpdates()
                }
                Button("Disable All Updates") {
                    disableAllUpdates()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Hub Properties")
        .onAppear {
            enableAllUpdates()
        }
    }
    
    func enableAllUpdates() {
        Task {
            do {
                try await hub.enableAllUpdates()
            } catch {
                print("Error", error)
            }
        }
    }
    
    func disableAllUpdates() {
        Task {
            do {
                try await hub.disableAllUpdates()
            } catch {
                print("Error", error)
            }
        }
    }
}
