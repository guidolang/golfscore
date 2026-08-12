import XCTest
@testable import GolfScore

@MainActor
final class RoundStoreTests: XCTestCase {
    func testInitialRoundContainsEighteenEmptyHoles() {
        let store = RoundStore(persistence: MemoryPersistence())

        XCTAssertEqual(store.round.holes.map(\.id), Array(1...18))
        XCTAssertTrue(store.round.holes.allSatisfy(\.strokes.isEmpty))
        XCTAssertEqual(store.totalStrokes, 0)
    }

    func testAddingStrokeRecordsTimestampAndUpdatesTotal() {
        let persistence = MemoryPersistence()
        let store = RoundStore(persistence: persistence)
        let timestamp = Date(timeIntervalSince1970: 1_234)

        XCTAssertTrue(store.addStroke(to: 4, at: timestamp))

        XCTAssertEqual(store.hole(number: 4).strokes.map(\.timestamp), [timestamp])
        XCTAssertEqual(store.totalStrokes, 1)
        XCTAssertEqual(persistence.savedRound, store.round)
    }

    func testHoleAllowsMoreThanNineStrokes() {
        let store = RoundStore(persistence: MemoryPersistence())

        for second in 0..<12 {
            XCTAssertTrue(store.addStroke(to: 1, at: Date(timeIntervalSince1970: TimeInterval(second))))
        }

        XCTAssertEqual(store.hole(number: 1).strokes.count, 12)
    }

    func testTotalCombinesAllHoles() {
        let store = RoundStore(persistence: MemoryPersistence())

        store.addStroke(to: 1)
        store.addStroke(to: 2)
        store.addStroke(to: 2)

        XCTAssertEqual(store.totalStrokes, 3)
    }

    func testStrokeSummaryUsesSingularOnlyForOne() {
        XCTAssertEqual(RoundStore.strokeSummary(for: 0), "0 Strokes")
        XCTAssertEqual(RoundStore.strokeSummary(for: 1), "1 Stroke")
        XCTAssertEqual(RoundStore.strokeSummary(for: 2), "2 Strokes")
    }

    func testDeletingStrokePersistsAndLeavesOtherStrokesInOrder() {
        let persistence = MemoryPersistence()
        let store = RoundStore(persistence: persistence)
        let first = Date(timeIntervalSince1970: 1)
        let second = Date(timeIntervalSince1970: 2)
        let third = Date(timeIntervalSince1970: 3)
        store.addStroke(to: 1, at: first)
        store.addStroke(to: 1, at: second)
        store.addStroke(to: 1, at: third)
        store.addStroke(to: 2)
        let strokeID = store.hole(number: 1).strokes[1].id

        XCTAssertTrue(store.deleteStroke(from: 1, id: strokeID))

        XCTAssertEqual(store.hole(number: 1).strokes.map(\.timestamp), [first, third])
        XCTAssertEqual(store.hole(number: 2).strokes.count, 1)
        XCTAssertEqual(store.totalStrokes, 3)
        XCTAssertEqual(persistence.savedRound, store.round)
    }

    func testDeletingUnknownStrokeDoesNotChangeRound() {
        let persistence = MemoryPersistence()
        let store = RoundStore(persistence: persistence)
        store.addStroke(to: 1)
        let originalRound = store.round

        XCTAssertFalse(store.deleteStroke(from: 1, id: UUID()))

        XCTAssertEqual(store.round, originalRound)
        XCTAssertEqual(persistence.savedRound, originalRound)
    }

    func testSavingNoteTrimsAndPersistsText() throws {
        let persistence = MemoryPersistence()
        let store = RoundStore(persistence: persistence)
        store.addStroke(to: 3)
        let strokeID = try XCTUnwrap(store.hole(number: 3).strokes.first?.id)

        XCTAssertTrue(store.saveNote("  Fairway bunker\n  ", for: strokeID, in: 3))

        XCTAssertEqual(store.hole(number: 3).strokes.first?.note, "Fairway bunker")
        XCTAssertEqual(persistence.savedRound, store.round)
    }

    func testSavingBlankNoteRemovesExistingNote() throws {
        let persistence = MemoryPersistence()
        let store = RoundStore(persistence: persistence)
        store.addStroke(to: 3)
        let strokeID = try XCTUnwrap(store.hole(number: 3).strokes.first?.id)
        store.saveNote("First note", for: strokeID, in: 3)

        XCTAssertTrue(store.saveNote(" \n\t ", for: strokeID, in: 3))

        XCTAssertNil(store.hole(number: 3).strokes.first?.note)
    }

    func testScorecardCSVExportsOnlyRecordedStrokesInOrder() {
        var round = RoundState.empty
        round.holes[0].strokes = [
            StrokeRecord(timestamp: Date(timeIntervalSince1970: 0), note: "Tee shot"),
            StrokeRecord(timestamp: Date(timeIntervalSince1970: 1), note: nil)
        ]
        round.holes[9].strokes = [
            StrokeRecord(timestamp: Date(timeIntervalSince1970: 2), note: "Approach")
        ]

        let csv = RoundStore.scorecardCSV(
            for: round,
            timeZone: TimeZone(secondsFromGMT: 2 * 60 * 60)!
        )

        XCTAssertEqual(
            csv,
            "Hole,Stroke,DateTime,Note\r\n"
                + "1,1,1970-01-01T02:00:00+02:00,Tee shot\r\n"
                + "1,2,1970-01-01T02:00:01+02:00,\r\n"
                + "10,1,1970-01-01T02:00:02+02:00,Approach"
        )
    }

    func testScorecardCSVEscapesCommasQuotesAndMultilineNotes() {
        var round = RoundState.empty
        round.holes[2].strokes = [
            StrokeRecord(
                timestamp: Date(timeIntervalSince1970: 0),
                note: "Bunker, near the lip\nSaid \"fore\""
            )
        ]

        let csv = RoundStore.scorecardCSV(
            for: round,
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertEqual(
            csv,
            "Hole,Stroke,DateTime,Note\r\n"
                + "3,1,1970-01-01T00:00:00Z,\"Bunker, near the lip\nSaid \"\"fore\"\"\""
        )
    }

    func testScorecardCSVForEmptyRoundContainsOnlyHeader() {
        XCTAssertEqual(
            RoundStore.scorecardCSV(for: .empty, timeZone: TimeZone(secondsFromGMT: 0)!),
            "Hole,Stroke,DateTime,Note"
        )
    }

    func testScorecardCSVDocumentUsesDatedCSVFilename() {
        let document = ScorecardCSVDocument(
            round: .empty,
            date: Date(timeIntervalSince1970: 0),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertEqual(document.filename, "GolfScore-1970-01-01.csv")
        XCTAssertEqual(String(decoding: document.contents, as: UTF8.self), "Hole,Stroke,DateTime,Note")
    }

    func testResetAllClearsEveryHole() {
        let store = RoundStore(persistence: MemoryPersistence())
        store.addStroke(to: 1)
        store.addStroke(to: 18)

        store.resetAll()

        XCTAssertTrue(store.round.holes.allSatisfy(\.strokes.isEmpty))
        XCTAssertEqual(store.totalStrokes, 0)
    }

    func testSavedRoundLoadsIntoNewStore() {
        var state = RoundState.empty
        state.holes[6].strokes = [StrokeRecord(timestamp: Date(timeIntervalSince1970: 42))]
        let persistence = MemoryPersistence(savedRound: state)

        let store = RoundStore(persistence: persistence)

        XCTAssertEqual(store.round, state)
        XCTAssertEqual(store.totalStrokes, 1)
    }

    func testInvalidSavedRoundFallsBackToCleanRound() {
        let invalid = RoundState(holes: [HoleScore(id: 1)])

        let store = RoundStore(persistence: MemoryPersistence(savedRound: invalid))

        XCTAssertEqual(store.round, .empty)
    }

    func testUserDefaultsPersistenceRoundTripAndInvalidDataRecovery() throws {
        let suiteName = "GolfScoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let persistence = UserDefaultsRoundPersistence(defaults: defaults)
        var state = RoundState.empty
        state.holes[0].strokes.append(StrokeRecord(timestamp: Date(timeIntervalSince1970: 99)))

        persistence.save(state)
        XCTAssertEqual(persistence.load(), state)

        defaults.set(Data("not json".utf8), forKey: UserDefaultsRoundPersistence.storageKey)
        XCTAssertNil(persistence.load())
    }

    func testTimestampFormatterUsesTwelveHourSystemSetting() throws {
        let calendar = testCalendar
        let stroke = try date(year: 2026, month: 7, day: 13, hour: 9, minute: 5)

        XCTAssertEqual(
            StrokeTimestampFormatter.string(
                for: stroke,
                calendar: calendar,
                locale: Locale(identifier: "en_US")
            ),
            "2026-07-13 09:05 AM"
        )
    }

    func testTimestampFormatterUsesTwentyFourHourSystemSetting() throws {
        let calendar = testCalendar
        let stroke = try date(year: 2026, month: 7, day: 4, hour: 21, minute: 7)

        XCTAssertEqual(
            StrokeTimestampFormatter.string(
                for: stroke,
                calendar: calendar,
                locale: Locale(identifier: "en_GB")
            ),
            "2026-07-04 21:07"
        )
    }

    func testPuttsReminderRequiresAtLeastTwoStrokes() {
        var reminder = PuttsReminder()

        XCTAssertFalse(reminder.shouldShow(for: []))
        XCTAssertFalse(reminder.shouldShow(for: [
            StrokeRecord(timestamp: Date(timeIntervalSince1970: 0))
        ]))
    }

    func testPuttsReminderDoesNotShowAtExactlySixtySeconds() {
        var reminder = PuttsReminder()

        XCTAssertFalse(reminder.shouldShow(for: [
            StrokeRecord(timestamp: Date(timeIntervalSince1970: 0)),
            StrokeRecord(timestamp: Date(timeIntervalSince1970: 60))
        ], relativeTo: Date(timeIntervalSince1970: 60)))
    }

    func testPuttsReminderShowsOnlyOnceWhenLastTwoStrokesAreMoreThanSixtySecondsApart() {
        var reminder = PuttsReminder()
        let strokes = [
            StrokeRecord(timestamp: Date(timeIntervalSince1970: 0)),
            StrokeRecord(timestamp: Date(timeIntervalSince1970: 10)),
            StrokeRecord(timestamp: Date(timeIntervalSince1970: 71))
        ]
        let currentDate = Date(timeIntervalSince1970: 71)

        XCTAssertTrue(reminder.shouldShow(for: strokes, relativeTo: currentDate))
        XCTAssertFalse(reminder.shouldShow(for: strokes, relativeTo: currentDate))
    }

    func testPuttsReminderShowsWhenLastStrokeIsJustUnderFiveMinutesOld() {
        var reminder = PuttsReminder()
        let strokes = [
            StrokeRecord(timestamp: Date(timeIntervalSince1970: 0)),
            StrokeRecord(timestamp: Date(timeIntervalSince1970: 61))
        ]

        XCTAssertTrue(reminder.shouldShow(
            for: strokes,
            relativeTo: Date(timeIntervalSince1970: 360.999)
        ))
    }

    func testPuttsReminderDoesNotShowWhenLastStrokeIsExactlyFiveMinutesOld() {
        var reminder = PuttsReminder()
        let strokes = [
            StrokeRecord(timestamp: Date(timeIntervalSince1970: 0)),
            StrokeRecord(timestamp: Date(timeIntervalSince1970: 61))
        ]

        XCTAssertFalse(reminder.shouldShow(
            for: strokes,
            relativeTo: Date(timeIntervalSince1970: 361)
        ))
    }

    func testPuttsReminderDoesNotShowWhenLastStrokeIsMoreThanFiveMinutesOld() {
        var reminder = PuttsReminder()
        let strokes = [
            StrokeRecord(timestamp: Date(timeIntervalSince1970: 0)),
            StrokeRecord(timestamp: Date(timeIntervalSince1970: 61))
        ]

        XCTAssertFalse(reminder.shouldShow(
            for: strokes,
            relativeTo: Date(timeIntervalSince1970: 362)
        ))
    }

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) throws -> Date {
        try XCTUnwrap(testCalendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
    }
}

private final class MemoryPersistence: RoundPersistence {
    var savedRound: RoundState?

    init(savedRound: RoundState? = nil) {
        self.savedRound = savedRound
    }

    func load() -> RoundState? {
        savedRound
    }

    func save(_ round: RoundState) {
        savedRound = round
    }
}
