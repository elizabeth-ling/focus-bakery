import SwiftUI
import UserNotifications

/// What the chrome's settings entry opens (spec 06).
///
/// Spec 13's list, whole and deliberately short: sound and haptics (12), the
/// daily reminder and its time (04), what permission the app actually has, and
/// the footer. Every toggle here is a decision the user should not have had to
/// make, so the screen is trimmed rather than grown — replaying onboarding is
/// the one candidate left, and it waits on there being onboarding to replay
/// (11).
///
/// The attribution in the footer is a licence obligation and not a courtesy
/// (14, `NOTICE.md`), which is why it shipped with the first version of this
/// screen rather than waiting for this one.
///
/// Every toggle writes straight through to `Settings` and asks the caller to
/// reconcile whatever it affects, because scheduling and audio both belong to
/// the app layer and never to a view (04, 06, 12).
struct SettingsSheetView: View {
    let authorization: UNAuthorizationStatus
    let onSoundChanged: () -> Void
    let onReminderChanged: () -> Void
    let onDismiss: () -> Void

    @State private var isSoundOn = true
    @State private var isHapticsOn = true
    @State private var isReminderOn = false
    @State private var reminderTime = Date()

    private let settings = Settings()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                feedback
                reminder
                if !authorization.deliversAlerts {
                    permissionNotice
                }
                footer
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(PixelInk.paper)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            isSoundOn = settings.soundEnabled
            isHapticsOn = settings.hapticsEnabled
            isReminderOn = settings.dailyReminderEnabled
            reminderTime = Self.date(from: settings.dailyReminderTime)
        }
        .onChange(of: isSoundOn) { _, isOn in
            settings.soundEnabled = isOn
            // The hum is already running and has to stop, or start, now (12).
            onSoundChanged()
        }
        .onChange(of: isHapticsOn) { _, isOn in
            // Nothing to reconcile: every cue reads this as it plays, so the
            // next one obeys it and there is no running state to correct.
            settings.hapticsEnabled = isOn
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
                .pixelFont()
                .foregroundStyle(PixelInk.heading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 12)
            Button("Done", action: onDismiss)
                .pixelFont()
                .foregroundStyle(PixelInk.heading)
        }
    }

    /// Spec 12's two switches. Both default to on, and with both off the app is
    /// still whole: nothing in it is announced by sound or by feel alone (13).
    private var feedback: some View {
        VStack(alignment: .leading, spacing: 12) {
            toggle("Sound", isOn: $isSoundOn)
            toggle("Haptics", isOn: $isHapticsOn)
        }
    }

    private var reminder: some View {
        VStack(alignment: .leading, spacing: 12) {
            toggle("Daily reminder", isOn: $isReminderOn)

            if isReminderOn {
                DatePicker(
                    selection: $reminderTime,
                    displayedComponents: .hourAndMinute
                ) {
                    Text("Remind me at")
                        .pixelFont()
                        .foregroundStyle(PixelInk.body)
                }
            }

            note("A nudge each morning, only on a day you haven't shown up yet.")
        }
    }

    private func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .pixelFont()
                .foregroundStyle(PixelInk.heading)
        }
        .tint(PixelInk.body)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .pixelFont()
            .foregroundStyle(PixelInk.body)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Stated plainly, once, where the user came looking — not as a banner over
    /// the room. Nothing in the app depends on delivery (04), so the copy says
    /// what stops working and no more.
    private var permissionNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Alerts are off")
                .pixelFont()
                .foregroundStyle(PixelInk.heading)
            Text("We can't tell you when a bake is done. The timer runs either way.")
                .pixelFont()
                .foregroundStyle(PixelInk.body)
                .fixedSize(horizontal: false, vertical: true)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                link("Open iOS Settings", to: url, ink: PixelInk.heading)
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// Spec 13's standard footer: version, privacy, support, attribution.
    ///
    /// The privacy line is a statement rather than a link because there is
    /// nothing to link to and nothing to disclose — the app has no networking
    /// code at all, and every byte it keeps is the JSON in Application Support
    /// and the preferences on this screen (02). A page saying that would be a
    /// page saying less than the sentence does.
    private var footer: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Focus Bakery \(Self.version)")
                .pixelFont()
                .foregroundStyle(PixelInk.heading)
            note("Everything stays on this phone. No account, no network, no analytics.")
            support
            attribution
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    /// The version travels in the subject line, because the first thing any
    /// answer needs is which build the sender is on.
    @ViewBuilder
    private var support: some View {
        if let url = URL(string: "mailto:\(Self.supportAddress)?subject=Focus%20Bakery%20\(Self.version)") {
            link("Get in touch", to: url, ink: PixelInk.heading)
                .accessibilityLabel("Get in touch, opens mail to \(Self.supportAddress)")
        }
    }

    /// Both licences, in the app, as they require (`NOTICE.md`). LimeZu's is the
    /// condition of using the pack at all (14); VileR's is ShareAlike on the
    /// font both text tiers are cut from (01).
    private var attribution: some View {
        VStack(alignment: .leading, spacing: 14) {
            credit("Art: Modern Interiors by LimeZu", "https://limezu.itch.io")
            credit("Font: PxPlus IBM CGA by VileR, CC BY-SA 4.0", "https://int10h.org/oldschool-pc-fonts/")
        }
    }

    @ViewBuilder
    private func credit(_ text: String, _ address: String) -> some View {
        if let url = URL(string: address) {
            link(text, to: url, ink: PixelInk.body)
        }
    }

    /// Underlined, and that is not decoration (13). The pixel tier has no tint
    /// colour of its own — every string on this sheet is one of two inks — so
    /// without a rule under it a link is indistinguishable from the prose beside
    /// it, which is the colour-alone failure one step further along: a control
    /// signalling that it is a control by nothing at all.
    private func link(_ text: String, to url: URL, ink: Color) -> some View {
        Link(destination: url) {
            Text(text)
                .pixelFont()
                .foregroundStyle(ink)
                .underline()
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    static let supportAddress = "elizabeth.ling@uwaterloo.ca"

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
