import SwiftUI
import UserNotifications

/// What the chrome's settings entry opens (spec 06): a tray down the leading
/// edge, the whole height of the viewport and most of its width.
///
/// A side bar rather than a sheet because the list is a column of switches and
/// a footer — a shape that wants height, which a bottom sheet is the one
/// presentation that cannot give it. It comes from the leading edge because
/// that is the end of the tray the gear is on, so the drawer opens out from
/// under its own control. It stops short of the trailing edge so a strip of the
/// room stays visible beside it, and the settings read as a drawer pulled over
/// the bakery rather than a screen the app navigated to.
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
struct SettingsTrayView: View {
    let layout: ChromeLayout
    let authorization: UNAuthorizationStatus
    let onSoundChanged: () -> Void
    let onReminderChanged: () -> Void
    let onDismiss: () -> Void

    @State private var isSoundOn = true
    @State private var isHapticsOn = true
    @State private var isReminderOn = false
    @State private var reminderTime = Date()
    /// How far the tray has been dragged towards its own edge. Never reset on
    /// a dismissal: the tray is being removed, and its state goes with it, so
    /// zeroing it here would snap it back a frame before it left.
    @State private var dragOffset: CGFloat = 0

    private let settings = Settings()

    /// The strip along the moving edge that the handle sits in and the drag is
    /// read from. The content is padded clear of it, so a drag that starts on
    /// the lane is never a drag that started on a switch.
    private static let handleLane: CGFloat = 24

    var body: some View {
        ZStack(alignment: .top) {
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
                .padding(.leading, 20)
                .padding(.trailing, Self.handleLane + 8)
                // The tray covers the viewport outright, so there is no safe
                // area left inside it to read: the status bar and the home
                // indicator are cleared with the insets the layout was handed.
                .padding(.top, layout.safeAreaTop + 20)
                .padding(.bottom, layout.safeAreaBottom + 20)
            }
            // The lane belongs to the handle. A scroll indicator rides the same
            // edge, and two thin vertical bars a few points apart is one bar
            // that means two things — the reader would find out which by
            // dragging the wrong one.
            .scrollIndicators(.hidden)
            // The status bar's band, in the tray's own material rather than its
            // paper. The clock is pinned to light content because it sits on the
            // chrome tray (06), and a tray that covers the viewport puts cream
            // under it — white glyphs on paper, and the room's dark strip beside
            // them, cannot both be read at one status-bar style. Leather here
            // means the whole band stays dark and the pinning stays true.
            PixelInk.leather
                .frame(height: layout.safeAreaTop)
            handle
        }
        .frame(width: layout.settingsTray.width, height: layout.settingsTray.height)
        .background(PixelInk.paper)
        .offset(x: dragOffset)
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

    /// What the bottom sheet used to get from the system: something to take
    /// hold of, and a swipe that closes. The sheet's grabber sat on the edge it
    /// moved along, so this one does too — down the trailing side, the edge that
    /// travels, rather than across the top.
    ///
    /// A bar rather than a capsule. Every corner in this app is a right angle on
    /// the grid (01), and a rounded pill would be the one curve on screen; the
    /// bar is 2 art pixels by 22 at the chrome's scale, so it magnifies like
    /// everything else.
    ///
    /// The drag reads from the whole lane, not from the bar, so the target is
    /// wide enough to find without looking. It is hidden from VoiceOver, which
    /// has "Done" — a swipe with no discrete position to land on is not a
    /// control that can be described.
    private var handle: some View {
        Rectangle()
            .fill(PixelInk.body.opacity(0.45))
            .frame(width: 4, height: 44)
            .frame(width: Self.handleLane)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(dismissDrag)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityHidden(true)
    }

    /// Follows the finger towards the tray's own edge and closes if it is taken
    /// far enough, or thrown hard enough that it would have got there.
    ///
    /// `min(0,)` is the same bound a sheet has at the top of its travel: the
    /// tray can be pulled shut but not dragged open past the edge it rests on.
    private var dismissDrag: some Gesture {
        DragGesture()
            .onChanged { drag in
                dragOffset = min(0, drag.translation.width)
            }
            .onEnded { drag in
                if drag.predictedEndTranslation.width < -layout.settingsTray.width / 3 {
                    onDismiss()
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { dragOffset = 0 }
                }
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
