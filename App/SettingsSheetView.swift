import SwiftUI
import UserNotifications

/// What the chrome's settings entry opens (spec 06).
///
/// Spec 13 owns this screen and will grow it: whether onboarding can be
/// replayed from here is 11's question. What is here is what already works —
/// sound and haptics (12), the daily reminder and its time (04), what permission
/// the app actually has, and the attribution the art and font licences require
/// (14, `NOTICE.md`). The attribution is an obligation rather than a polish
/// item, so it ships with the first screen that can hold it.
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
                attribution
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
                .font(ChromeFont.pixel())
                .foregroundStyle(PixelInk.heading)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 12)
            Button("Done", action: onDismiss)
                .font(ChromeFont.pixel())
                .foregroundStyle(PixelInk.heading)
        }
    }

    /// Spec 12's two switches. Both default to on, and with both off the app is
    /// still whole: nothing in it is announced by sound or by feel alone (13).
    private var feedback: some View {
        VStack(alignment: .leading, spacing: 12) {
            toggle("Sound", isOn: $isSoundOn)
            toggle("Haptics", isOn: $isHapticsOn)
            // Worth saying out loud rather than leaving to be discovered: this
            // is a focus app, and the fear it has to answer is that starting a
            // bake will stop the music you started it for.
            note("The bakery mixes under whatever you're listening to, and goes quiet with your silent switch.")
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
                        .font(ChromeFont.pixel())
                        .foregroundStyle(PixelInk.body)
                }
            }

            note("A nudge each morning, only on a day you haven't shown up yet.")
        }
    }

    private func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(ChromeFont.pixel())
                .foregroundStyle(PixelInk.heading)
        }
        .tint(PixelInk.body)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(ChromeFont.pixel())
            .foregroundStyle(PixelInk.body)
            .fixedSize(horizontal: false, vertical: true)
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
