import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ScanView()
                .frame(minWidth: 320, maxWidth: .infinity, minHeight: 320, maxHeight: .infinity)
        }
    }
}
