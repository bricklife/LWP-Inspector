import SwiftUI

struct ScanView: View {
    @StateObject var scanner = Scanner()
    
    var body: some View {
        NavigationView {
            Form {
                if scanner.discoveredPeripherals.isEmpty {
                    if scanner.isScanning {
                        Text("Scanning...")
                    } else {
                        Text("Not found")
                    }
                } else {
                    ForEach(scanner.discoveredPeripherals.elements, id: \.key) { key, p in
                        let name = p.name ?? "Unknown"
                        let rssi = p.rssi
                        NavigationLink {
                            MainView(uuid: p.identifier)
                        } label: {
                            HStack {
                                Text(name)
                                Spacer()
                                Text(rssi.description)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(scanner.isScanning ? "Scanning..." : "Scan Hubs")
            .toolbar {
                if scanner.isScanning {
                    Button("Stop") {
                        scanner.stopScan()
                    }
                } else {
                    Button("Start") {
                        scanner.startScan()
                    }
                }
            }
        }
        .onAppear {
            scanner.startScan()
        }
    }
}

struct ScanView_Previews: PreviewProvider {
    static var previews: some View {
        ScanView()
    }
}
