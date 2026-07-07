import SwiftUI

@main
struct ChaselogApp: App {
    @StateObject private var store = ChaselogStore()
    @StateObject private var purchases = PurchaseManager()
    @AppStorage("chaselog_haptics_enabled") private var hapticsEnabled: Bool = true

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .environmentObject(purchases)
                .preferredColorScheme(.light)
                .onAppear {
                    Haptics.enabled = hapticsEnabled
                }
        }
    }
}
