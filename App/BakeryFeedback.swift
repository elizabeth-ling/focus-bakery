import AVFoundation
import Observation
import OSLog
import UIKit

/// The app's one point of contact with the speaker and the Taptic Engine.
///
/// It decides nothing about *what* things sound like — `BakeryCue` owns that —
/// and nothing about when a bake finishes. What it owns is the pair of rules
/// spec 12 will not bend on: the hum runs for exactly as long as the app is in
/// front of the user with sound switched on, and a finished bake gets its
/// moment exactly once.
///
/// It lives in the app layer rather than in `BakeryScene` deliberately (05, 12).
/// Audio outlives individual scene instances: the scene is thrown away and
/// rebuilt on every size change, and a hum that restarted when the keyboard
/// appeared would be a hum with a seam in it after all.
@MainActor
@Observable
final class BakeryFeedback {
    /// Ambient is the category that satisfies both of spec 12's absolutes at
    /// once, which is why it is the category and not a starting point.
    ///
    /// It is silenced by the Ring/Silent switch — the app must not talk over a
    /// room the user has silenced — and it mixes rather than interrupting, so
    /// the music or podcast someone is focusing to keeps playing untouched.
    /// `.playback` would break the first rule, `.soloAmbient` the second, and
    /// breaking the second in a focus app is fatal.
    static let category: AVAudioSession.Category = .ambient

    private let client: FeedbackClient
    private let settings: Settings

    private var isForeground = true
    private var isHumming = false

    /// The bake whose moment has already been played.
    ///
    /// One slot is enough: only one bake exists at a time (02), so a new
    /// session brings a new id and this one stops mattering.
    private var announcedSessionID: BakeSession.ID?

    /// The client is passed rather than defaulted, for the reason
    /// `BakeryNotifications` documents: a default argument is evaluated outside
    /// this actor, and `.system` belongs to it.
    init(client: FeedbackClient, settings: Settings = Settings()) {
        self.client = client
        self.settings = settings
        client.configureSession(Self.category)
    }

    /// Sound and haptic together, each gated by its own switch.
    ///
    /// Read from `Settings` at the moment of playing rather than cached, so a
    /// toggle takes effect on the very next cue with nothing to keep in sync.
    func play(_ cue: BakeryCue) {
        if settings.soundEnabled { client.playSound(cue.soundName) }
        if settings.hapticsEnabled { client.playHaptic(cue.haptic) }
    }

    /// The moment a finished bake is owed, played exactly once.
    ///
    /// Two paths arrive here and they are mutually exclusive per bake — the
    /// treat landing at the end of the deliver walk, or the alert for a bake
    /// that finished while the app was away (03, 05) — but "mutually exclusive"
    /// is a property of the caller, and the acceptance criterion is *exactly
    /// once*. So the guard lives here, where it is one comparison and can be
    /// tested, rather than being argued from the call sites. It also covers the
    /// case the call sites cannot: a scene rebuilt mid-walk settles straight
    /// back into delivering and places the treat again.
    func announce(_ session: BakeSession) {
        let cue: BakeryCue
        switch session.outcome {
        case .completed: cue = .completion
        case .burned: cue = .burned
        case .inProgress: return
        }
        guard session.id != announcedSessionID else { return }
        announcedSessionID = session.id
        play(cue)
    }

    func enterForeground() {
        isForeground = true
        syncHum()
    }

    /// The app should not be audible while the user is elsewhere (12). There is
    /// no background audio mode in v1, so this is a stop and not a duck.
    func leaveForeground() {
        isForeground = false
        syncHum()
    }

    /// The sound switch was flipped in settings (13). Cues need no telling —
    /// they read the setting as they play — but the hum is already running and
    /// has to stop, or start, now rather than at the next foreground.
    func settingsChanged() {
        syncHum()
    }

    private func syncHum() {
        let wanted = isForeground && settings.soundEnabled
        guard wanted != isHumming else { return }
        isHumming = wanted
        if wanted {
            client.activateSession(true)
            client.startAmbient(BakeryCue.ambientSoundName)
        } else {
            client.stopAmbient()
            // Let go of the session as well as the sound: an app holding an
            // active audio session while backgrounded is an app the system —
            // and the user's Now Playing controls — still consider to be in the
            // mix.
            client.activateSession(false)
        }
    }
}

/// The `AVFoundation` and `UIKit` calls this app makes, as closures.
///
/// An injection point rather than an abstraction, for the same reason
/// `NotificationCenterClient` is one: what the app *asked* for can be asserted
/// in a test, while what a speaker and a Taptic Engine actually did cannot be
/// judged without a device in your hand.
@MainActor
struct FeedbackClient {
    var configureSession: (AVAudioSession.Category) -> Void
    var activateSession: (Bool) -> Void
    var startAmbient: (String) -> Void
    var stopAmbient: () -> Void
    var playSound: (String) -> Void
    var playHaptic: (BakeryCue.Haptic) -> Void

    static let system = FeedbackClient(
        configureSession: { SystemFeedback.shared.configureSession($0) },
        activateSession: { SystemFeedback.shared.activateSession($0) },
        startAmbient: { SystemFeedback.shared.startAmbient($0) },
        stopAmbient: { SystemFeedback.shared.stopAmbient() },
        playSound: { SystemFeedback.shared.play(sound: $0) },
        playHaptic: { SystemFeedback.shared.play(haptic: $0) }
    )
}

/// The system side of `FeedbackClient`: the players and the generators, and the
/// only code here that a unit test cannot reach.
///
/// It holds its players because `AVAudioPlayer` stops the instant it is
/// released — one built inside a closure and dropped on the way out plays
/// nothing at all — and because decoding is the slow part, and a cue that
/// decodes on the tap it is meant to accompany arrives after it.
///
/// Placeholder-first, exactly as the room is (05): a sound whose file is not in
/// the bundle is silence and never a crash, so the app runs with any subset of
/// the audio in place.
@MainActor
private final class SystemFeedback {
    static let shared = SystemFeedback()

    private let logger = Logger(subsystem: "com.focusbakery.FocusBakery", category: "audio")
    private var cues: [String: AVAudioPlayer] = [:]
    private var ambient: AVAudioPlayer?

    // Held rather than made per tap: the engine stays warm for a moment after
    // use, and a generator built for a single tap is cold for exactly that tap.
    private let notification = UINotificationFeedbackGenerator()
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let light = UIImpactFeedbackGenerator(style: .light)

    func configureSession(_ category: AVAudioSession.Category) {
        do {
            try AVAudioSession.sharedInstance().setCategory(category)
        } catch {
            // Nothing in the app depends on audio, so a session that will not
            // configure costs the user the sound and no more. Failing loudly
            // here would take the bakery down over a hum.
            logger.error("Could not set the audio category: \(error.localizedDescription, privacy: .public)")
        }
    }

    func activateSession(_ active: Bool) {
        do {
            try AVAudioSession.sharedInstance().setActive(active)
        } catch {
            logger.error("Could not set the audio session active=\(active): \(error.localizedDescription, privacy: .public)")
        }
    }

    func startAmbient(_ name: String) {
        if ambient == nil { ambient = loaded(name) }
        guard let ambient else { return }
        ambient.numberOfLoops = -1
        // Faded in rather than cut in. Returning to the app is a door opening
        // on a room that was already there, and a bed that snaps to full volume
        // announces itself as a file starting instead.
        ambient.volume = 0
        ambient.play()
        ambient.setVolume(1, fadeDuration: 1.2)
    }

    func stopAmbient() {
        // Stopped outright, not faded: backgrounding is the one caller, and the
        // system may suspend the process before a fade could finish — which
        // would leave the app audible from the app switcher, the exact thing
        // spec 12 rules out.
        ambient?.stop()
    }

    func play(sound name: String) {
        if cues[name] == nil { cues[name] = loaded(name) }
        guard let player = cues[name] else { return }
        player.currentTime = 0
        player.play()
    }

    func play(haptic: BakeryCue.Haptic) {
        switch haptic {
        case .success: notification.notificationOccurred(.success)
        case .soft: soft.impactOccurred()
        case .light: light.impactOccurred()
        }
    }

    private func loaded(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            logger.notice("\(name, privacy: .public).wav is not in the bundle; that cue is silent")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            logger.error("Could not open \(name, privacy: .public).wav: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
