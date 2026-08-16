import SwiftUI
import UserNotifications

/// What the chrome's settings entry opens (spec 06).
///
/// Spec 13 owns this screen and will grow it: sound and haptics arrive with 12,
/// and whether onboarding can be replayed from here is 11's question. What is
/// here is what already works — the daily reminder and its time (04), what
/// permission the app actually has, and the attribution the art and font
/// licences require (14, `NOTICE.md`). The attribution is an obligation rather
/// than a polish item, so it ships with the first screen that can hold it.
///
/// The reminder writes straight through to `Settings` and asks the caller to
/// reconcile, because scheduling belongs to the app layer and never to a view
/// (04, 06).
struct SettingsSheetView: View {
    let authorization: UNAuthorizationStatus
    let onReminderChanged: () -> Void
    let onDismiss: () -> Void

    @State private var isReminderOn = false
    @State private var reminderTime = Date()

    private let settings = Settings()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                reminder
                if !authorization.deliversAlerts {
                    permissionNotice
                }
                attribution
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(PixelInk.paper)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            isReminderOn = settings.dailyReminderEnabled
            reminderTime = Self.date(from: settings.dailyReminderTime)
        }
        .onChange(of: isReminderOn) { _, isOn in
            settings.dailyReminderEnabled = isOn
            onReminderChanged()
        }
        .onChange(of: reminderTime) { _, time in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
            settings.dailyReminderTime = TimeOfDay(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
            onReminderChanged()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Settings")
                .font(ChromeFont.pixel())
                .foregroundStyle(PixelInk.heading)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 12)
            Button("Done", action: onDismiss)
                .font(ChromeFont.pixel())
                .foregroundStyle(PixelInk.heading)
        }
    }

    private var reminder: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $isReminderOn) {
                Text("Daily reminder")
                    .font(ChromeFont.pixel())
                    .foregroundStyle(PixelInk.heading)
            }
            .tint(PixelInk.body)

            if isReminderOn {
                DatePicker(
                    selection: $reminderTime,
                    displayedComponents: .hourAndMinute
                ) {
                    Text("Remind me at")
                        .font(ChromeFont.pixel())
                        .foregroundStyle(PixelInk.body)
                }
            }

            Text("A nudge each morning, only on a day you haven't shown up yet.")
                .font(ChromeFont.pixel())
                .foregroundStyle(PixelInk.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Stated plainly, once, where the user came looking — not as a banner over
    /// the room. Nothing in the app depends on delivery (04), so the copy says
    /// what stops working and no more.
    private var permissionNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Alerts are off")
                .font(ChromeFont.pixel())
                .foregroundStyle(PixelInk.heading)
            Text("We can't tell you when a bake is done. The timer runs either way.")
                .font(ChromeFont.pixel())
                .foregroundStyle(PixelInk.body)
                .fixedSize(horizontal: false, vertical: true)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open iOS Settings", destination: url)
                    .font(ChromeFont.pixel())
                    .foregroundStyle(PixelInk.heading)
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// Both licences, in the app, as they require (`NOTICE.md`). LimeZu's is the
    /// condition of using the pack at all (14); VileR's is ShareAlike on the
    /// font both text tiers are cut from (01).
    private var attribution: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Focus Bakery \(Self.version)")
                .font(ChromeFont.pixel())
                .foregroundStyle(PixelInk.heading)
            credit("Art: Modern Interiors by LimeZu", "https://limezu.itch.io")
            credit("Font: PxPlus IBM CGA by VileR, CC BY-SA 4.0", "https://int10h.org/oldschool-pc-fonts/")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func credit(_ text: String, _ address: String) -> some View {
        if let url = URL(string: address) {
            Link(destination: url) {
                Text(text)
                    .font(ChromeFont.pixel())
                    .foregroundStyle(PixelInk.body)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private static func date(from time: TimeOfDay) -> Date {
        let now = Date()
        return Calendar.current.date(
            bySettingHour: time.hour, minute: time.minute, second: 0, of: now
        ) ?? now
    }
}
