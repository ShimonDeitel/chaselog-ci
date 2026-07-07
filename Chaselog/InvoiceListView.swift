import SwiftUI

struct InvoiceListView: View {
    @EnvironmentObject private var store: ChaselogStore
    @EnvironmentObject private var purchases: PurchaseManager

    @State private var sheetMode: InvoiceSheetMode?
    @State private var deletingInvoice: Invoice?
    @State private var savedToast: String?

    private var sortedInvoices: [Invoice] {
        store.invoices.sorted { a, b in
            if a.status != b.status { return a.status == .sent }
            return a.dueDate < b.dueDate
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CLTheme.backdrop.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header

                        summaryBanner

                        if store.invoices.isEmpty {
                            emptyState
                        } else {
                            VStack(spacing: 12) {
                                ForEach(sortedInvoices) { invoice in
                                    InvoiceCard(invoice: invoice) {
                                        sheetMode = .edit(invoice)
                                    } onTogglePaid: {
                                        Haptics.success()
                                        if invoice.status == .paid {
                                            store.markUnpaid(invoice.id)
                                        } else {
                                            store.markPaid(invoice.id)
                                        }
                                    } onDelete: {
                                        Haptics.warning()
                                        deletingInvoice = invoice
                                    }
                                }
                            }
                            .padding(.horizontal, 18)
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: store.invoices)

                            if !purchases.isPro {
                                Text("Free plan: \(store.invoices.count)/\(ChaselogStore.freeInvoiceLimit) invoices used")
                                    .font(.caption)
                                    .foregroundStyle(CLTheme.inkFaded)
                                    .padding(.horizontal, 18)
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }

                if let name = savedToast {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                            Text(name)
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(CLTheme.accent)
                        .clipShape(Capsule())
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .allowsHitTesting(false)
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $sheetMode) { mode in
                switch mode {
                case .paywall:
                    PaywallView().environmentObject(purchases)
                case .add, .edit:
                    InvoiceEditSheet(mode: mode) { client, description, amount, issueDate, dueDate in
                        switch mode {
                        case .add:
                            store.addInvoice(clientName: client, description: description, amount: amount, issueDate: issueDate, dueDate: dueDate, isPro: purchases.isPro)
                            Haptics.success()
                            showToast("Invoice logged")
                        case .edit(let invoice):
                            store.updateInvoice(invoice.id, clientName: client, description: description, amount: amount, issueDate: issueDate, dueDate: dueDate)
                        case .paywall:
                            break
                        }
                    }
                }
            }
            .confirmationDialog(
                "Remove invoice for \(deletingInvoice?.clientName ?? "")?",
                isPresented: Binding(
                    get: { deletingInvoice != nil },
                    set: { if !$0 { deletingInvoice = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    if let deletingInvoice {
                        store.deleteInvoice(deletingInvoice.id)
                    }
                    deletingInvoice = nil
                }
                Button("Cancel", role: .cancel) { deletingInvoice = nil }
            }
        }
    }

    private func showToast(_ text: String) {
        savedToast = text
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if savedToast == text { savedToast = nil }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Chaselog")
                    .font(CLTheme.titleFont)
                    .foregroundStyle(CLTheme.ink)
                Text("Chase what's owed")
                    .font(.caption)
                    .foregroundStyle(CLTheme.inkFaded)
            }
            Spacer()
            Button {
                if store.canAddInvoice(isPro: purchases.isPro) {
                    sheetMode = .add
                } else {
                    sheetMode = .paywall
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(CLTheme.accent)
            }
            .accessibilityIdentifier("addInvoiceButton")
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private var summaryBanner: some View {
        HStack(spacing: 0) {
            statTile(label: "Outstanding", value: store.outstandingTotal, color: CLTheme.accent)
            Divider().frame(height: 34)
            statTile(label: "Overdue", value: store.overdueTotal, color: CLTheme.hot)
            Divider().frame(height: 34)
            statTile(label: "Collected", value: store.collectedTotal, color: CLTheme.fresh)
        }
        .padding(.vertical, 14)
        .background(CLTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(CLTheme.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 18)
    }

    private func statTile(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(CLTheme.inkFaded)
            Text(value, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 34))
                .foregroundStyle(CLTheme.inkFaded)
            Text("No invoices logged yet. Tap + to record your first one.")
                .font(.subheadline)
                .foregroundStyle(CLTheme.inkFaded)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 40)
    }
}

/// The signature visual: a card with a left-edge "heat bar" whose color and
/// intensity track the aging bucket — green when current/paid, warming to
/// amber near the due date, and hot-to-scorching red as it ages past due.
private struct InvoiceCard: View {
    let invoice: Invoice
    let onEdit: () -> Void
    let onTogglePaid: () -> Void
    let onDelete: () -> Void

    private var heatColor: Color {
        if invoice.status == .paid { return CLTheme.fresh }
        switch invoice.agingBucket {
        case .current: return CLTheme.fresh
        case .dueSoon: return CLTheme.warming
        case .overdue30: return CLTheme.hot
        case .overdue60, .overdue90, .overdue90Plus: return CLTheme.scorching
        }
    }

    private var statusLabel: String {
        if invoice.status == .paid { return "Paid" }
        if invoice.isOverdue { return "\(invoice.daysOverdue)d overdue" }
        let daysUntil = -invoice.daysOverdue
        return daysUntil == 0 ? "Due today" : "Due in \(daysUntil)d"
    }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(heatColor)
                .frame(width: 6)
                .padding(.vertical, 10)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(invoice.clientName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CLTheme.ink)
                HStack(spacing: 6) {
                    Text(statusLabel)
                        .font(.caption)
                        .foregroundStyle(heatColor)
                    if !invoice.description.isEmpty {
                        Text("\u{00B7}")
                            .foregroundStyle(CLTheme.inkFaded)
                        Text(invoice.description)
                            .font(.caption)
                            .foregroundStyle(CLTheme.inkFaded)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.leading, 12)

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(invoice.amount, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(CLTheme.ink)

                Menu {
                    Button(action: onTogglePaid) {
                        Label(invoice.status == .paid ? "Mark Unpaid" : "Mark Paid", systemImage: invoice.status == .paid ? "arrow.uturn.backward" : "checkmark.circle")
                    }
                    Button(action: onEdit) {
                        Label("Edit Invoice", systemImage: "pencil")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("Remove Invoice", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(CLTheme.inkFaded)
                        .padding(6)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("invoiceMenu_\(invoice.clientName)")
            }
            .padding(.trailing, 14)
        }
        .padding(.vertical, 8)
        .background(CLTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(CLTheme.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    InvoiceListView()
        .environmentObject(ChaselogStore())
        .environmentObject(PurchaseManager())
}
