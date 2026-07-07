import Foundation

enum InvoiceStatus: String, Codable, CaseIterable, Identifiable {
    case sent = "Sent"
    case paid = "Paid"

    var id: String { rawValue }
}

struct Invoice: Identifiable, Codable, Equatable {
    let id: UUID
    var clientName: String
    var description: String
    var amount: Double
    var issueDate: Date
    var dueDate: Date
    var status: InvoiceStatus
    var paidDate: Date?
    var createdDate: Date

    init(
        id: UUID = UUID(),
        clientName: String,
        description: String,
        amount: Double,
        issueDate: Date = Date(),
        dueDate: Date,
        status: InvoiceStatus = .sent,
        paidDate: Date? = nil,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.clientName = clientName
        self.description = description
        self.amount = amount
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.status = status
        self.paidDate = paidDate
        self.createdDate = createdDate
    }

    /// Days overdue (positive) or until due (negative), measured from today.
    var daysOverdue: Int {
        let comps = Calendar.current.dateComponents([.day], from: dueDate, to: Date())
        return comps.day ?? 0
    }

    var isOverdue: Bool {
        status == .sent && daysOverdue > 0
    }

    /// Aging bucket used for the heat-scale color and grouping.
    enum AgingBucket: String, CaseIterable, Identifiable {
        case current = "Current"
        case dueSoon = "Due Soon"
        case overdue30 = "1-30 Days Overdue"
        case overdue60 = "31-60 Days Overdue"
        case overdue90 = "61-90 Days Overdue"
        case overdue90Plus = "90+ Days Overdue"

        var id: String { rawValue }
    }

    var agingBucket: AgingBucket {
        if status == .paid { return .current }
        let d = daysOverdue
        if d <= -3 { return .current }
        if d <= 0 { return .dueSoon }
        if d <= 30 { return .overdue30 }
        if d <= 60 { return .overdue60 }
        if d <= 90 { return .overdue90 }
        return .overdue90Plus
    }
}

/// Per-client running total: outstanding balance and days-late average, used
/// to spot chronically slow-paying clients.
struct ClientSummary: Identifiable {
    var clientName: String
    var outstandingTotal: Double
    var paidTotal: Double
    var invoiceCount: Int
    var averageDaysToPayLate: Double
    var oldestOpenInvoiceDate: Date?

    var id: String { clientName }
}

/// Pro bonus feature: milestone badges awarded on collection behavior.
enum Milestone: String, CaseIterable, Identifiable {
    case firstInvoice = "First Invoice"
    case firstPaid = "First Payment Collected"
    case tenInvoices = "Ten Invoices Logged"
    case fiveThousandCollected = "$5,000 Collected"
    case fastCollector = "Fast Collector"
    case cleanSlate = "Clean Slate"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .firstInvoice: return "doc.text.fill"
        case .firstPaid: return "checkmark.seal.fill"
        case .tenInvoices: return "10.circle.fill"
        case .fiveThousandCollected: return "banknote.fill"
        case .fastCollector: return "bolt.fill"
        case .cleanSlate: return "sparkles"
        }
    }

    var detail: String {
        switch self {
        case .firstInvoice: return "Logged your first invoice."
        case .firstPaid: return "Marked your first invoice as paid."
        case .tenInvoices: return "Logged 10 invoices."
        case .fiveThousandCollected: return "Collected $5,000 or more total."
        case .fastCollector: return "Average payment lag under 7 days."
        case .cleanSlate: return "No overdue invoices right now."
        }
    }
}
