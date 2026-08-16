import AVFoundation
import Foundation
import Testing
@testable import FocusBakery

/// A stand-in for the speaker and the Taptic Engine, recording what the app
/// asked them for. What they then did is a device question.
@MainActor
final class FakeFeedbackSystem {
    private(set) var category: AVAudioSession.Category?
    private(set) var isSessionActive = false
    private(set) var isHumming = false
    private(set) var humStarts = 0
    private(set) var ambientName: String?
    private(set) var sounds: [String] = []
    private(set) var haptics: [BakeryCue.Haptic] = []

    var client: FeedbackClient {
        FeedbackClient(
            configureSession: { [self] in category = $0 },
            activateSession: { [self] in isSessionActive = $0 },
            startAmbient: { [self] name in
                ambientName = name
                isHumming = true
                humStarts += 1
            },
            stopAmbient: { [self] in isHumming = false },
            playSound: { [self] in sounds.append($0) },
            playHaptic: { [self] in haptics.append($0) }
        )
    }
}

/// Spec 12's rules, driven through the object that talks to the system: what
/// would have been played, and what would have been kept quiet.
@MainActor
@Suite("Sound and haptics")
struct BakeryFeedbackTests {
    private let system = FakeFeedbackSystem()
    private let settings = Settings(defaults: makeTemporaryDefaults())
    private let feedback: BakeryFeedback

    init() {
        feedback = BakeryFeedback(client: system.client, settings: settings)
    }

    private func bake(_ outcome: BakeSession.Outcome) -> BakeSession {
        BakeSession(
            recipeID: .chocolateChipCookie,
            startDate: instant(2026, 8, 16, 9),
            durationMinutes: 25,
            outcome: outcome
        )
    }

    // MARK: - The two absolutes

    /// The half of spec 12's first two acceptance criteria that can be checked
    /// without a device. `.ambient` is *the* category that satisfies both — it
    /// is silenced by the Ring/Silent switch and it mixes rather than
    /// interrupting — so pinning the category pins the behaviour. That it is
    /// then honoured is the system's job, and the device pass's to confirm.
    @Test("The app asks for a category that neither interrupts nor overrides silent")
    func usesTheAmbientCategory() {
        #expect(system.category == .ambient)
        #expect(BakeryFeedback.category == .ambient)
    }

    // MARK: - The hum

    @Test("The hum runs while the app is in front of the user and not otherwise")
    func humFollowsTheForeground() {
        #expect(system.isHumming == false)

        feedback.enterForeground()
        #expect(system.isHumming)
        #expect(system.isSessionActive)
        #expect(system.ambientName == BakeryCue.ambientSoundName)

        feedback.leaveForeground()
        #expect(system.isHumming == false)
        // The session goes with it: an app still in the mix while backgrounded
        // is an app the system has not finished with.
        #expect(system.isSessionActive == false)

        feedback.enterForeground()
        #expect(system.isHumming)
    }

    @Test("Foregrounding twice does not start a second hum over the first")
    func humIsNotRestartedWhileItRuns() {
        feedback.enterForeground()
        feedback.enterForeground()
        feedback.settingsChanged()

        #expect(system.humStarts == 1)
    }

    @Test("The sound switch takes the hum with it, immediately and both ways")
    func humFollowsTheSoundSetting() {
        feedback.enterForeground()
        #expect(system.isHumming)

        settings.soundEnabled = false
        feedback.settingsChanged()
        #expect(system.isHumming == false)
        #expect(system.isSessionActive == false)

        settings.soundEnabled = true
        feedback.settingsChanged()
        #expect(system.isHumming)
    }

    @Test("Turning sound on while the app is away does not start it humming")
    func humNeverStartsInTheBackground() {
        feedback.enterForeground()
        feedback.leaveForeground()

        settings.soundEnabled = false
        feedback.settingsChanged()
        settings.soundEnabled = true
        feedback.settingsChanged()

        #expect(system.isHumming == false)
    }

    // MARK: - The completion moment

    @Test("A finished bake rings once, however many times it is announced")
    func completionIsAnnouncedExactlyOnce() {
        let finished = bake(.completed)

        // Both of spec 12's paths, on the same bake: the treat landing at the
        // end of the walk, and the alert for one resolved on return. A scene
        // rebuilt mid-walk is a third, and lands here too.
        feedback.announce(finished)
        feedback.announce(finished)
        feedback.announce(finished)

        #expect(system.sounds == [BakeryCue.completion.soundName])
        #expect(system.haptics == [.success])
    }

    @Test("The next bake gets its own moment")
    func eachBakeIsAnnouncedInTurn() {
        feedback.announce(bake(.completed))
        feedback.announce(bake(.completed))

        #expect(system.sounds.count == 2)
        #expect(system.haptics == [.success, .success])
    }

    @Test("A burn is announced, and never as a completion")
    func burnHasItsOwnTreatment() {
        feedback.announce(bake(.burned))

        #expect(system.sounds == [BakeryCue.burned.soundName])
        #expect(system.haptics == [.soft])
        #expect(BakeryCue.burned.soundName != BakeryCue.completion.soundName)
        #expect(BakeryCue.burned.haptic != BakeryCue.completion.haptic)
    }

    @Test("A bake still running has nothing to announce, and spends nothing")
    func inFlightBakeIsNotAnnounced() {
        var session = bake(.inProgress)
        feedback.announce(session)

        #expect(system.sounds.isEmpty)
        #expect(system.haptics.isEmpty)

        // And the moment is still owed when that same bake finishes.
        session.outcome = .completed
        feedback.announce(session)

        #expect(system.sounds == [BakeryCue.completion.soundName])
    }

    // MARK: - The switches

    @Test("Sound off silences the app without taking the haptics with it")
    func soundSwitchOnlySilences() {
        settings.soundEnabled = false

        feedback.play(.step)

        #expect(system.sounds.isEmpty)
        #expect(system.haptics == [.light])
    }

    @Test("Haptics off stills the phone without silencing it")
    func hapticSwitchOnlyStills() {
        settings.hapticsEnabled = false

        feedback.play(.purchase)

        #expect(system.sounds == [BakeryCue.purchase.soundName])
        #expect(system.haptics.isEmpty)
    }

    @Test("With both switches off nothing plays, and the moment is still spent")
    func bothOffLeavesNothingBroken() {
        settings.soundEnabled = false
        settings.hapticsEnabled = false

        feedback.enterForeground()
        let finished = bake(.completed)
        feedback.announce(finished)

        #expect(system.isHumming == false)
        #expect(system.sounds.isEmpty)
        #expect(system.haptics.isEmpty)

        // Spent, not deferred: turning the sound back on afterwards must not
        // ring for a bake the user has already been shown.
        settings.soundEnabled = true
        settings.hapticsEnabled = true
        feedback.announce(finished)

        #expect(system.sounds.isEmpty)
        #expect(system.haptics.isEmpty)
    }

    @Test("A switch flipped mid-session is obeyed by the very next cue")
    func switchesTakeEffectImmediately() {
        feedback.play(.step)
        settings.soundEnabled = false
        feedback.play(.step)
        settings.soundEnabled = true
        feedback.play(.step)

        #expect(system.sounds.count == 2)
        #expect(system.haptics.count == 3)
    }

    // MARK: - The vocabulary

    @Test("Every cue names its own sound, and only the payoff is heavy")
    func cuesAreDistinctAndRestrained() {
        let names = Set(BakeryCue.allCases.map(\.soundName))
        #expect(names.count == BakeryCue.allCases.count)
        #expect(!names.contains(BakeryCue.ambientSoundName))

        // Spec 12 spends the notification-weight haptic exactly once.
        let heavy = BakeryCue.allCases.filter { $0.haptic == .success }
        #expect(heavy == [.completion])
    }
}
