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

    func testHoleCannotExceedNineStrokes() {
        let store = RoundStore(persistence: MemoryPersistence())

        for second in 0..<RoundStore.maximumStrokesPerHole {
            XCTAssertTrue(store.addStroke(to: 1, at: Date(timeIntervalSince1970: TimeInterval(second))))
        }

        XCTAssertFalse(store.addStroke(to: 1))
        XCTAssertEqual(store.hole(number: 1).strokes.count, 9)
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

    func testResetHoleLeavesOtherHolesUntouched() {
        let store = RoundStore(persistence: MemoryPersistence())
        store.addStroke(to: 1)
        store.addStroke(to: 2)

        store.resetHole(1)

        XCTAssertTrue(store.hole(number: 1).strokes.isEmpty)
        XCTAssertEqual(store.hole(number: 2).strokes.count, 1)
        XCTAssertEqual(store.totalStrokes, 1)
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

    func testTimestampFormatterShowsTimeOnlyForToday() throws {
        let calendar = testCalendar
        let reference = try date(year: 2026, month: 7, day: 13, hour: 16, minute: 30)
        let stroke = try date(year: 2026, month: 7, day: 13, hour: 9, minute: 5)

        XCTAssertEqual(
            StrokeTimestampFormatter.string(for: stroke, relativeTo: reference, calendar: calendar),
            "9:05 AM"
        )
    }

    func testTimestampFormatterIncludesDateForPreviousDay() throws {
        let calendar = testCalendar
        let reference = try date(year: 2026, month: 7, day: 13, hour: 16, minute: 30)
        let stroke = try date(year: 2026, month: 7, day: 4, hour: 21, minute: 7)

        XCTAssertEqual(
            StrokeTimestampFormatter.string(for: stroke, relativeTo: reference, calendar: calendar),
            "07/04/2026 9:07 PM"
        )
    }

    func testTimestampFormatterChangesFormatAcrossMidnight() throws {
        let calendar = testCalendar
        let reference = try date(year: 2026, month: 7, day: 14, hour: 0, minute: 1)
        let stroke = try date(year: 2026, month: 7, day: 13, hour: 23, minute: 59)

        XCTAssertEqual(
            StrokeTimestampFormatter.string(for: stroke, relativeTo: reference, calendar: calendar),
            "07/13/2026 11:59 PM"
        )
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
