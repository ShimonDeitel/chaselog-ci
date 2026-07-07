import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ChaselogStore
    @EnvironmentObject private var purchases: PurchaseManager
    @AppStorage("chaselog_haptics_enabled") private var hapticsEnabled: Bool = true
    /// Pro bonus feature: configurable "overdue alert" threshold, in days.
    @AppStorage("chaselog_alert_days") private var alertDays: Int = 30

    @State private var showingDeleteConfirm = false
    @State private var sheetMode: InvoiceSheetMode?

    var body: some View {
        NavigationStack {
            ZStack {
                CLTheme.backdrop.ignoresSafeArea()

                Form {
                    Section {
                        if purchases.isPro {
                            HStack {
                                Image(systemName: "checkmark.seal.fill").foregroundStyle(CLTheme.accent)
                                Text("Chaselog Pro active")
                                    .foregroundStyle(CLTheme.ink)
                            }
                        } else {
                            Button {
                                sheetMode = .paywall
                            } label: {
                                HStack {
                                    Image(systemName: "star.fill").foregroundStyle(CLTheme.warming)
                                    Text("Unlock Chaselog Pro")
                                        .foregroundStyle(CLTheme.ink)
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(CLTheme.inkFaded)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(CLTheme.card)

                    if purchases.isPro {
                        Section("Client Balances") {
                            if store.clientSummaries.isEmpty {
                                Text("Add invoices to see per-client balances.")
                                    .font(.caption)
                                    .foregroundStyle(CLTheme.inkFaded)
                            } else {
                                ForEach(store.clientSummaries) { summary in
                                    clientRow(summary)
                                }
                            }
                        }
                        .listRowBackground(CLTheme.card)

                        Section("Aging Breakdown") {
                            if store.agingBreakdown.isEmpty {
                                Text("No open invoices to age.")
                                    .font(.caption)
                                    .foregroundStyle(CLTheme.inkFaded)
                            } else {
                                ForEach(store.agingBreakdown, id: \.bucket) { row in
                                    HStack {
                                        Text(row.bucket.rawValue)
                                            .foregroundStyle(CLTheme.ink)
                                        Spacer()
                                        Text("\(row.count)")
                                            .font(.caption)
                                            .foregroundStyle(CLTheme.inkFaded)
                                        Text(row.total, format: .currency(code: "USD").precision(.fractionLength(0)))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(CLTheme.accent)
                                    }
                                }
                            }
                        }
                        .listRowBackground(CLTheme.card)

                        Section("Overdue Alert Threshold") {
                            Stepper("Flag invoices over \(alertDays) days late", value: $alertDays, in: 1...180)
                                .foregroundStyle(CLTheme.ink)
                                .accessibilityIdentifier("alertDaysStepper")

                            let flagged = store.invoices.filter { $0.isOverdue && $0.daysOverdue >= alertDays }
                            if flagged.isEmpty {
                                Text("Nobody has crossed that threshold.")
                                    .font(.caption)
                                    .foregroundStyle(CLTheme.inkFaded)
                            } else {
                                ForEach(flagged) { invoice in
                                    HStack {
                                        Image(systemName: "flame.fill")
                                            .foregroundStyle(CLTheme.scorching)
                                        Text(invoice.clientName)
                                            .foregroundStyle(CLTheme.ink)
                                        Spacer()
                                        Text("\(invoice.daysOverdue)d overdue")
                                            .font(.caption)
                                            .foregroundStyle(CLTheme.inkFaded)
                                    }
                                }
                            }
                        }
                        .listRowBackground(CLTheme.card)

                        Section("Milestone Badges") {
                            let earned = store.earnedMilestones
                            ForEach(Milestone.allCases) { milestone in
                                let isEarned = earned.contains(milestone)
                                HStack {
                                    Image(systemName: milestone.symbolName)
                                        .foregroundStyle(isEarned ? CLTheme.accent : CLTheme.inkFaded.opacity(0.4))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(milestone.rawValue)
                                            .foregroundStyle(isEarned ? CLTheme.ink : CLTheme.inkFaded)
                                        Text(milestone.detail)
                                            .font(.caption2)
                                            .foregroundStyle(CLTheme.inkFaded)
                                    }
                                    Spacer()
                                    if isEarned {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(CLTheme.fresh)
                                    }
                                }
                            }
                        }
                        .listRowBackground(CLTheme.card)
                    } else {
                        Section("Pro Features") {
                            Text("Unlock per-client balances, aging breakdowns, the overdue alert threshold, and milestone badges with Chaselog Pro.")
                                .font(.caption)
                                .foregroundStyle(CLTheme.inkFaded)
                        }
                        .listRowBackground(CLTheme.card)
                    }

                    Section("Invoices") {
                        Button {
                            if store.canAddInvoice(isPro: purchases.isPro) {
                                sheetMode = .add
                            } else {
                                sheetMode = .paywall
                            }
                        } label: {
                            Label("Add Invoice", systemImage: "plus.circle")
                                .foregroundStyle(CLTheme.accent)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settingsAddInvoiceButton")

                        if !purchases.isPro {
                            Text("\(store.invoices.count)/\(ChaselogStore.freeInvoiceLimit) free invoices used")
                                .font(.caption)
                                .foregroundStyle(CLTheme.inkFaded)
                        }
                    }
                    .listRowBackground(CLTheme.card)

                    Section("Preferences") {
                        Toggle(isOn: $hapticsEnabled) {
                            Label("Haptics", systemImage: "hand.tap.fill")
                                .foregroundStyle(CLTheme.ink)
                        }
                        .tint(CLTheme.accent)
                        .onChange(of: hapticsEnabled) { _, newValue in
                            Haptics.enabled = newValue
                        }

                        Button {
                            Task { await purchases.restore() }
                        } label: {
                            Label("Restore Purchases", systemImage: "arrow.clockwise")
                                .foregroundStyle(CLTheme.ink)
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowBackground(CLTheme.card)

                    Section("About") {
                        Link(destination: URL(string: "https://shimondeitel.github.io/chaselog-site/privacy.html")!) {
                            Label("Privacy Policy", systemImage: "hand.raised.fill")
                                .foregroundStyle(CLTheme.ink)
                        }
                        Link(destination: URL(string: "https://shimondeitel.github.io/chaselog-site/support.html")!) {
                            Label("Support", systemImage: "questionmark.circle")
                                .foregroundStyle(CLTheme.ink)
                        }
                        Link(destination: URL(string: "mailto:s0533495227@gmail.com")!) {
                            Label("Contact Support", systemImage: "envelope.fill")
                                .foregroundStyle(CLTheme.ink)
                        }
                        HStack {
                            Text("Version").foregroundStyle(CLTheme.ink)
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                .foregroundStyle(CLTheme.inkFaded)
                        }
                    }
                    .listRowBackground(CLTheme.card)

                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Label("Delete All Data", systemImage: "trash.fill")
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowBackground(CLTheme.card)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .sheet(item: $sheetMode) { mode in
                switch mode {
                case .paywall:
                    PaywallView().environmentObject(purchases)
                case .add, .edit:
                    InvoiceEditSheet(mode: mode) { client, description, amount, issueDate, dueDate in
                        switch mode {
                        case .add:
                            store.addInvoice(clientName: client, description: description, amount: amount, issueDate: issueDate, dueDate: dueDate, isPro: purchases.isPro)
                        case .edit(let invoice):
                            store.updateInvoice(invoice.id, clientName: client, description: description, amount: amount, issueDate: issueDate, dueDate: dueDate)
                        case .paywall:
                            break
                        }
                    }
                }
            }
            .alert("Delete All Data?", isPresented: $showingDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Everything", role: .destructive) {
                    store.deleteAllData()
                }
            } message: {
                Text("This permanently removes every logged invoice. This cannot be undone.")
            }
        }
        .dismissKeyboardOnTap()
    }

    private func clientRow(_ summary: ClientSummary) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(summary.clientName)
                    .foregroundStyle(CLTheme.ink)
                Text("\(summary.invoiceCount) invoice\(summary.invoiceCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(CLTheme.inkFaded)
            }
            Spacer()
            Text(summary.outstandingTotal, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(summary.outstandingTotal > 0 ? CLTheme.hot : CLTheme.fresh)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("clientRow_\(summary.clientName)")
    }
}

#Preview {
    SettingsView()
        .environmentObject(ChaselogStore())
        .environmentObject(PurchaseManager())
}
