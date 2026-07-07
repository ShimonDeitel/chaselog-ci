import SwiftUI

/// One unified sheet enum per screen — stacking multiple `.sheet(item:)` or
/// `.alert(...)` modifiers on the same view is a known SwiftUI bug (only the
/// last-declared one reliably fires). Route every sheet through this enum.
enum InvoiceSheetMode: Identifiable {
    case add
    case edit(Invoice)
    case paywall

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let invoice): return invoice.id.uuidString
        case .paywall: return "paywall"
        }
    }
}

struct InvoiceEditSheet: View {
    let mode: InvoiceSheetMode
    let onSave: (String, String, Double, Date, Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var clientName: String
    @State private var description: String
    @State private var amountText: String
    @State private var issueDate: Date
    @State private var dueDate: Date

    init(mode: InvoiceSheetMode, onSave: @escaping (String, String, Double, Date, Date) -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .edit(let invoice):
            _clientName = State(initialValue: invoice.clientName)
            _description = State(initialValue: invoice.description)
            _amountText = State(initialValue: String(format: "%.2f", invoice.amount))
            _issueDate = State(initialValue: invoice.issueDate)
            _dueDate = State(initialValue: invoice.dueDate)
        default:
            _clientName = State(initialValue: "")
            _description = State(initialValue: "")
            _amountText = State(initialValue: "")
            _issueDate = State(initialValue: Date())
            _dueDate = State(initialValue: Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date())
        }
    }

    private var title: String {
        if case .edit = mode { return "Edit Invoice" }
        return "New Invoice"
    }

    private var parsedAmount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private var isValid: Bool {
        !clientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && parsedAmount > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Client") {
                    TextField("Client name", text: $clientName)
                        .accessibilityIdentifier("clientNameField")

                    TextField("Description (optional)", text: $description)
                        .accessibilityIdentifier("descriptionField")
                }

                Section("Amount") {
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("amountField")
                }

                Section("Dates") {
                    DatePicker("Issue date", selection: $issueDate, displayedComponents: .date)
                        .accessibilityIdentifier("issueDatePicker")
                    DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                        .accessibilityIdentifier("dueDatePicker")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(clientName, description, parsedAmount, issueDate, dueDate)
                        dismiss()
                    }
                    .accessibilityIdentifier("invoiceSaveButton")
                    .disabled(!isValid)
                }
            }
        }
        .dismissKeyboardOnTap()
    }
}
