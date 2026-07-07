import Foundation

@MainActor
final class ChaselogStore: ObservableObject {
    @Published private(set) var invoices: [Invoice] = []

    static let freeInvoiceLimit = 20

    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("chaselog_invoices.json")
        if ProcessInfo.processInfo.arguments.contains("-uiTestReset") {
            try? FileManager.default.removeItem(at: fileURL)
        }
        load()
        if invoices.isEmpty {
            seedDefaults()
        }
    }

    private func seedDefaults() {
        let cal = Calendar.current
        invoices = [
            Invoice(
                clientName: "Nova Studio",
                description: "Landing page redesign",
                amount: 1800,
                issueDate: cal.date(byAdding: .day, value: -50, to: Date())!,
                dueDate: cal.date(byAdding: .day, value: -20, to: Date())!,
                status: .sent
            ),
            Invoice(
                clientName: "Brightline Co",
                description: "Monthly retainer",
                amount: 950,
                issueDate: cal.date(byAdding: .day, value: -10, to: Date())!,
                dueDate: cal.date(byAdding: .day, value: 4, to: Date())!,
                status: .sent
            )
        ]
        save()
    }

    func canAddInvoice(isPro: Bool) -> Bool {
        isPro || invoices.count < Self.freeInvoiceLimit
    }

    @discardableResult
    func addInvoice(clientName: String, description: String, amount: Double, issueDate: Date, dueDate: Date, isPro: Bool) -> Bool {
        let trimmed = clientName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, amount > 0, canAddInvoice(isPro: isPro) else { return false }
        let invoice = Invoice(clientName: trimmed, description: description, amount: amount, issueDate: issueDate, dueDate: dueDate)
        invoices.append(invoice)
        save()
        return true
    }

    func updateInvoice(_ id: UUID, clientName: String, description: String, amount: Double, issueDate: Date, dueDate: Date) {
        let trimmed = clientName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, amount > 0, let idx = invoices.firstIndex(where: { $0.id == id }) else { return }
        invoices[idx].clientName = trimmed
        invoices[idx].description = description
        invoices[idx].amount = amount
        invoices[idx].issueDate = issueDate
        invoices[idx].dueDate = dueDate
        save()
    }

    func markPaid(_ id: UUID) {
        guard let idx = invoices.firstIndex(where: { $0.id == id }) else { return }
        invoices[idx].status = .paid
        invoices[idx].paidDate = Date()
        save()
    }

    func markUnpaid(_ id: UUID) {
        guard let idx = invoices.firstIndex(where: { $0.id == id }) else { return }
        invoices[idx].status = .sent
        invoices[idx].paidDate = nil
        save()
    }

    func deleteInvoice(_ id: UUID) {
        invoices.removeAll { $0.id == id }
        save()
    }

    func deleteAllData() {
        invoices = []
        seedDefaults()
    }

    // MARK: - Derived data

    var outstandingTotal: Double {
        invoices.filter { $0.status == .sent }.reduce(0) { $0 + $1.amount }
    }

    var overdueTotal: Double {
        invoices.filter { $0.isOverdue }.reduce(0) { $0 + $1.amount }
    }

    var collectedTotal: Double {
        invoices.filter { $0.status == .paid }.reduce(0) { $0 + $1.amount }
    }

    /// Pro bonus feature: per-client outstanding balance and lateness.
    var clientSummaries: [ClientSummary] {
        let grouped = Dictionary(grouping: invoices, by: { $0.clientName })
        return grouped.map { name, list in
            let outstanding = list.filter { $0.status == .sent }.reduce(0) { $0 + $1.amount }
            let paid = list.filter { $0.status == .paid }.reduce(0) { $0 + $1.amount }
            let paidList = list.filter { $0.status == .paid && $0.paidDate != nil }
            let lateDays: [Double] = paidList.map { inv in
                let days = Calendar.current.dateComponents([.day], from: inv.dueDate, to: inv.paidDate!).day ?? 0
                return Double(days)
            }
            let avgLate = lateDays.isEmpty ? 0 : lateDays.reduce(0, +) / Double(lateDays.count)
            let oldestOpen = list.filter { $0.status == .sent }.map(\.dueDate).min()
            return ClientSummary(clientName: name, outstandingTotal: outstanding, paidTotal: paid, invoiceCount: list.count, averageDaysToPayLate: avgLate, oldestOpenInvoiceDate: oldestOpen)
        }.sorted { $0.outstandingTotal > $1.outstandingTotal }
    }

    /// Pro bonus feature: aging bucket breakdown for the whole book.
    var agingBreakdown: [(bucket: Invoice.AgingBucket, total: Double, count: Int)] {
        Invoice.AgingBucket.allCases.compactMap { bucket in
            let list = invoices.filter { $0.status == .sent && $0.agingBucket == bucket }
            guard !list.isEmpty else { return nil }
            return (bucket, list.reduce(0) { $0 + $1.amount }, list.count)
        }
    }

    /// Milestone badges earned so far.
    var earnedMilestones: [Milestone] {
        var earned: [Milestone] = []
        if !invoices.isEmpty { earned.append(.firstInvoice) }
        if invoices.contains(where: { $0.status == .paid }) { earned.append(.firstPaid) }
        if invoices.count >= 10 { earned.append(.tenInvoices) }
        if collectedTotal >= 5000 { earned.append(.fiveThousandCollected) }
        let paidWithDates = invoices.filter { $0.status == .paid && $0.paidDate != nil }
        if !paidWithDates.isEmpty {
            let avgDays = paidWithDates.map { inv -> Double in
                Double(Calendar.current.dateComponents([.day], from: inv.issueDate, to: inv.paidDate!).day ?? 0)
            }.reduce(0, +) / Double(paidWithDates.count)
            if avgDays < 7 { earned.append(.fastCollector) }
        }
        if !invoices.contains(where: { $0.isOverdue }) && !invoices.isEmpty { earned.append(.cleanSlate) }
        return earned
    }

    // MARK: - Persistence

    private struct Snapshot: Codable {
        var invoices: [Invoice]
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode(Snapshot.self, from: data) {
            invoices = decoded.invoices
        }
    }

    private func save() {
        let snapshot = Snapshot(invoices: invoices)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
