import SwiftUI

/// Chaselog's identity: a cool slate-blue backdrop with an amber "aging heat"
/// accent that intensifies as invoices get older, plus a calm green for paid.
/// Deliberately distinct from every sibling app's palette (Envelo's warm
/// white/coral/teal, and any cream/ink-navy/amber "luxury ledger" family) —
/// this one reads as a dashboard, not a ledger book.
enum CLTheme {
    static let backdrop = Color(red: 0.933, green: 0.941, blue: 0.953)      // cool slate-white
    static let card = Color.white
    static let cardBorder = Color(red: 0.831, green: 0.851, blue: 0.878)

    static let ink = Color(red: 0.106, green: 0.145, blue: 0.204)          // deep navy-charcoal
    static let inkFaded = Color(red: 0.106, green: 0.145, blue: 0.204).opacity(0.56)

    static let accent = Color(red: 0.145, green: 0.353, blue: 0.588)        // slate blue (brand)
    static let accentDeep = Color(red: 0.098, green: 0.259, blue: 0.443)

    // Aging heat scale: fresh -> current, warming -> due soon, hot -> overdue.
    static let fresh = Color(red: 0.204, green: 0.596, blue: 0.400)         // green, current/paid
    static let warming = Color(red: 0.902, green: 0.678, blue: 0.176)       // amber, due soon
    static let hot = Color(red: 0.882, green: 0.353, blue: 0.235)           // orange-red, overdue
    static let scorching = Color(red: 0.729, green: 0.153, blue: 0.133)     // deep red, badly overdue

    static let rule = Color.black.opacity(0.06)

    static let titleFont = Font.system(.title2, design: .rounded).weight(.bold)
    static let displayFont = Font.system(size: 40, weight: .bold, design: .rounded)
    static let headlineFont = Font.system(.headline, design: .rounded).weight(.semibold)
}

struct DismissKeyboardOnTap: ViewModifier {
    func body(content: Content) -> some View {
        content.simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
        )
    }
}

extension View {
    func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardOnTap())
    }
}

enum Haptics {
    static var enabled: Bool = true

    static func light() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
