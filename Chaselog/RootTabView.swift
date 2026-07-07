import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            InvoiceListView()
                .tabItem {
                    Label("Home", systemImage: "doc.text.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(CLTheme.accent)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(CLTheme.card)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    RootTabView()
        .environmentObject(ChaselogStore())
        .environmentObject(PurchaseManager())
}
