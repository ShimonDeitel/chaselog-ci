import XCTest
@testable import Chaselog

final class ChaselogTests: XCTestCase {
    func testInvoiceDefaults() {
        let due = Calendar.current.date(byAdding: .day, value: 14, to: Date())!
        let invoice = Invoice(clientName: "Test", description: "Work", amount: 500, dueDate: due)
        XCTAssertEqual(invoice.amount, 500)
        XCTAssertEqual(invoice.status, .sent)
    }

    @MainActor
    func testStoreAddInvoiceRespectsFreeLimit() {
        let store = ChaselogStore()
        for i in store.invoices { store.deleteInvoice(i.id) }
        let due = Calendar.current.date(byAdding: .day, value: 14, to: Date())!
        for i in 0..<ChaselogStore.freeInvoiceLimit {
            XCTAssertTrue(store.addInvoice(clientName: "Client \(i)", description: "", amount: 100, issueDate: Date(), dueDate: due, isPro: false))
        }
        XCTAssertFalse(store.addInvoice(clientName: "Overflow", description: "", amount: 100, issueDate: Date(), dueDate: due, isPro: false))
        XCTAssertTrue(store.addInvoice(clientName: "Overflow", description: "", amount: 100, issueDate: Date(), dueDate: due, isPro: true))
    }

    @MainActor
    func testAddInvoiceRejectsEmptyNameOrZeroAmount() {
        let store = ChaselogStore()
        for i in store.invoices { store.deleteInvoice(i.id) }
        let due = Calendar.current.date(byAdding: .day, value: 14, to: Date())!
        XCTAssertFalse(store.addInvoice(clientName: "   ", description: "", amount: 100, issueDate: Date(), dueDate: due, isPro: false))
        XCTAssertFalse(store.addInvoice(clientName: "Valid Client", description: "", amount: 0, issueDate: Date(), dueDate: due, isPro: false))
        XCTAssertEqual(store.invoices.count, 0)
    }

    @MainActor
    func testTotalsAndMarkPaid() {
        let store = ChaselogStore()
        for i in store.invoices { store.deleteInvoice(i.id) }
        let due = Calendar.current.date(byAdding: .day, value: 14, to: Date())!
        store.addInvoice(clientName: "Nova", description: "", amount: 300, issueDate: Date(), dueDate: due, isPro: false)
        XCTAssertEqual(store.outstandingTotal, 300, accuracy: 0.01)
        XCTAssertEqual(store.collectedTotal, 0, accuracy: 0.01)
        let invoice = store.invoices[0]
        store.markPaid(invoice.id)
        XCTAssertEqual(store.outstandingTotal, 0, accuracy: 0.01)
        XCTAssertEqual(store.collectedTotal, 300, accuracy: 0.01)
    }

    @MainActor
    func testOverdueDetection() {
        let store = ChaselogStore()
        for i in store.invoices { store.deleteInvoice(i.id) }
        let pastDue = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        store.addInvoice(clientName: "Late Client", description: "", amount: 200, issueDate: Calendar.current.date(byAdding: .day, value: -30, to: Date())!, dueDate: pastDue, isPro: false)
        let invoice = store.invoices[0]
        XCTAssertTrue(invoice.isOverdue)
        XCTAssertGreaterThanOrEqual(invoice.daysOverdue, 9)
        XCTAssertEqual(store.overdueTotal, 200, accuracy: 0.01)
    }

    @MainActor
    func testAgingBucketClassification() {
        let store = ChaselogStore()
        for i in store.invoices { store.deleteInvoice(i.id) }
        let due40DaysAgo = Calendar.current.date(byAdding: .day, value: -40, to: Date())!
        store.addInvoice(clientName: "Aged Client", description: "", amount: 150, issueDate: Calendar.current.date(byAdding: .day, value: -60, to: Date())!, dueDate: due40DaysAgo, isPro: false)
        let invoice = store.invoices[0]
        XCTAssertEqual(invoice.agingBucket, .overdue60)
    }

    @MainActor
    func testClientSummaryAggregation() {
        let store = ChaselogStore()
        for i in store.invoices { store.deleteInvoice(i.id) }
        let due = Calendar.current.date(byAdding: .day, value: 14, to: Date())!
        store.addInvoice(clientName: "Repeat Client", description: "First", amount: 100, issueDate: Date(), dueDate: due, isPro: false)
        store.addInvoice(clientName: "Repeat Client", description: "Second", amount: 200, issueDate: Date(), dueDate: due, isPro: false)
        let summary = store.clientSummaries.first { $0.clientName == "Repeat Client" }
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.outstandingTotal ?? 0, 300, accuracy: 0.01)
        XCTAssertEqual(summary?.invoiceCount ?? 0, 2)
    }

    @MainActor
    func testMilestonesAwardedProgressively() {
        let store = ChaselogStore()
        for i in store.invoices { store.deleteInvoice(i.id) }
        XCTAssertFalse(store.earnedMilestones.contains(.firstInvoice))
        let due = Calendar.current.date(byAdding: .day, value: 14, to: Date())!
        store.addInvoice(clientName: "First", description: "", amount: 100, issueDate: Date(), dueDate: due, isPro: false)
        XCTAssertTrue(store.earnedMilestones.contains(.firstInvoice))
        XCTAssertFalse(store.earnedMilestones.contains(.firstPaid))
        store.markPaid(store.invoices[0].id)
        XCTAssertTrue(store.earnedMilestones.contains(.firstPaid))
    }

    @MainActor
    func testUpdateInvoiceModifiesFields() {
        let store = ChaselogStore()
        for i in store.invoices { store.deleteInvoice(i.id) }
        let due = Calendar.current.date(byAdding: .day, value: 14, to: Date())!
        store.addInvoice(clientName: "Original", description: "Old", amount: 100, issueDate: Date(), dueDate: due, isPro: false)
        let invoice = store.invoices[0]
        let newDue = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        store.updateInvoice(invoice.id, clientName: "Renamed", description: "New", amount: 250, issueDate: Date(), dueDate: newDue)
        XCTAssertEqual(store.invoices[0].clientName, "Renamed")
        XCTAssertEqual(store.invoices[0].description, "New")
        XCTAssertEqual(store.invoices[0].amount, 250, accuracy: 0.01)
    }

    @MainActor
    func testDeleteAllDataReseeds() {
        let store = ChaselogStore()
        store.deleteAllData()
        XCTAssertFalse(store.invoices.isEmpty)
    }

    @MainActor
    func testMarkUnpaidRevertsStatus() {
        let store = ChaselogStore()
        for i in store.invoices { store.deleteInvoice(i.id) }
        let due = Calendar.current.date(byAdding: .day, value: 14, to: Date())!
        store.addInvoice(clientName: "Flippy", description: "", amount: 100, issueDate: Date(), dueDate: due, isPro: false)
        let invoice = store.invoices[0]
        store.markPaid(invoice.id)
        XCTAssertEqual(store.invoices[0].status, .paid)
        store.markUnpaid(invoice.id)
        XCTAssertEqual(store.invoices[0].status, .sent)
        XCTAssertNil(store.invoices[0].paidDate)
    }
}
