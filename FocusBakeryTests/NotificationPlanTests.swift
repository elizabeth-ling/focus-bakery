import Foundation
import Testing
@testable import FocusBakery

/// Spec 04's scheduling policy, driven as a pure function of persisted state —
/// which is everything about it that can be judged off a device.
@Suite("Notification plan")
struct NotificationPlanTests {
    private func bake(startingAt start: Date, minutes: Int = 25) -> BakeSession {
        BakeSession(recipeID: .chocolateChipCookie, startDate: start, durationMinutes: minutes)
    }

    // MARK: - Completion alert

    @Test("A running bake plans one alert, at its end date")
    func runningBakePlansItsCompletion() {
        let now = instant(2026, 8, 14, 9)
        let session = bake(startingAt: now)
        let state = SessionState(active: session)

        let planned = NotificationPlan.completion(for: state, now: now.addingTimeInterval(60))

        #expect(planned?.identifier == NotificationPlan.completionIdentifier)
        #expect(planned?.trigger == .instant(session.endDate))
        #expect(planned?.title == "Fresh out of the oven")
        #expect(planned?.body.contains("chocolate chip cookie") == true)
    }

    @Test("An idle bakery plans no completion alert")
    func idleBakeryPlansNothing() {
        #expect(NotificationPlan.completion(for: SessionState(), now: instant(2026, 8, 14, 9)) == nil)
    }

    @Test("A departure that dooms the bake takes its alert with it")
    func doomedBakePlansNoCompletion() {
        let start = instant(2026, 8, 14, 9)
        // Backgrounded with the whole bake still to run: under spec 03's burn
        // policy this is already a burn, and a burn owes nobody a celebration.
        let state = SessionState(active: bake(startingAt: start), leftForegroundAt: start)

        #expect(NotificationPlan.completion(for: state, now: start.addingTimeInterval(1)) == nil)
    }

    @Test("A departure inside the final grace keeps the alert")
    func departureTooLateToBurnKeepsTheCompletion() {
        let start = instant(2026, 8, 14, 9)
        let session = bake(startingAt: start)
        // Left with less than the grace left to run, so the bake survives the
        // absence — and this is precisely the case where the user is not looking
        // at the app when it finishes, so the alert is the whole point.
        let leftAt = session.endDate.addingTimeInterval(-(BurnPolicy.backgroundGrace - 5))
        let state = SessionState(active: session, leftForegroundAt: leftAt)

        #expect(NotificationPlan.completion(for: state, now: leftAt)?.trigger == .instant(session.endDate))
    }

    @Test("A bake whose end date has already passed plans nothing")
    func finishedBakePlansNothing() {
        let start = instant(2026, 8, 14, 9)
        let session = bake(startingAt: start)
        let state = SessionState(active: session)

        #expect(NotificationPlan.completion(for: state, now: session.endDate) == nil)
    }

    @Test("A burned bake in the slot plans nothing")
    func resolvedSessionPlansNothing() {
        let start = instant(2026, 8, 14, 9)
        var burned = bake(startingAt: start)
        burned.outcome = .burned

        #expect(NotificationPlan.completion(for: SessionState(active: burned), now: start) == nil)
    }

    @Test("Start, cancel, start again — the second bake reuses the one identifier")
    func restartingReusesTheIdentifier() {
        let start = instant(2026, 8, 14, 9)
        let first = NotificationPlan.completion(for: SessionState(active: bake(startingAt: start)), now: start)

        // Cancelled: nothing is planned, so reconciling removes what was pending.
        #expect(NotificationPlan.completion(for: SessionState(), now: start) == nil)

        let restart = start.addingTimeInterval(120)
        let second = NotificationPlan.completion(for: SessionState(active: bake(startingAt: restart)), now: restart)

        // Same identifier, later end date: adding it replaces the first rather
        // than leaving a stale request behind it.
        #expect(second?.identifier == first?.identifier)
        #expect(second?.trigger != first?.trigger)
    }

    // MARK: - Daily reminder

    private func reminders(
        enabled: Bool = true,
        at time: TimeOfDay = .defaultReminder,
        openedToday: Bool = false,
        now: Date,
        timeZone: TimeZone = .newYork
    ) -> [PlannedNotification] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return NotificationPlan.dailyReminders(
            enabled: enabled, at: time, openedToday: openedToday, now: now, calendar: calendar
        )
    }

    @Test("The off switch plans no reminders at all")
    func disabledReminderPlansNothing() {
        #expect(reminders(enabled: false, now: instant(2026, 8, 14, 7)).isEmpty)
    }

    @Test("An untouched day is reminded at the configured local time")
    func reminderLandsAtTheConfiguredTime() {
        let planned = reminders(at: TimeOfDay(hour: 7, minute: 30), now: instant(2026, 8, 14, 6))

        #expect(planned.count == NotificationPlan.reminderWindowDays)
        #expect(planned.first?.identifier == NotificationPlan.reminderIdentifier(dayOffset: 0))
        #expect(planned.first?.title == "Your bakery's ready to open")
        #expect(planned.first?.trigger == .localTime(
            DateComponents(year: 2026, month: 8, day: 14, hour: 7, minute: 30)
        ))
        // Every day in the window is its own dated request; a repeating trigger
        // could not skip a day the user had already shown up for.
        #expect(Set(planned.map(\.identifier)).count == planned.count)
        #expect(planned.last?.trigger == .localTime(
            DateComponents(year: 2026, month: 8, day: 20, hour: 7, minute: 30)
        ))
    }

    @Test("A day the user has already opened is skipped")
    func openedTodayIsSkipped() {
        let planned = reminders(openedToday: true, now: instant(2026, 8, 14, 7))

        #expect(planned.count == NotificationPlan.reminderWindowDays - 1)
        #expect(planned.first?.trigger == .localTime(
            DateComponents(year: 2026, month: 8, day: 15, hour: 9, minute: 0)
        ))
    }

    @Test("A reminder time that has already passed today is skipped")
    func pastReminderTimeIsSkipped() {
        let planned = reminders(now: instant(2026, 8, 14, 14))

        #expect(planned.count == NotificationPlan.reminderWindowDays - 1)
        #expect(planned.allSatisfy { $0.identifier != NotificationPlan.reminderIdentifier(dayOffset: 0) })
    }

    @Test("Reminders are wall-clock, so they follow the user into a new timezone")
    func remindersAreLocalWallClock() {
        let morningInTokyo = instant(2026, 8, 15, 6, in: .tokyo)
        let planned = reminders(now: morningInTokyo, timeZone: .tokyo)

        // Same instant is still the 14th in New York; the reminder is planned
        // against the calendar the user is actually living in.
        #expect(planned.first?.trigger == .localTime(
            DateComponents(year: 2026, month: 8, day: 15, hour: 9, minute: 0)
        ))
    }

    @Test("A stored reminder time outside a day is clamped rather than trusted")
    func timeOfDayIsClamped() {
        #expect(TimeOfDay(minutesFromMidnight: -30) == TimeOfDay(hour: 0, minute: 0))
        #expect(TimeOfDay(minutesFromMidnight: 5_000) == TimeOfDay(hour: 23, minute: 59))
        #expect(TimeOfDay(hour: 9, minute: 0).minutesFromMidnight == 540)
    }
}
