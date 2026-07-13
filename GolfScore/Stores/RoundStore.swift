import Foundation
import Observation

@MainActor
@Observable
final class RoundStore {
    private(set) var round: RoundState
    @ObservationIgnored private let persistence: any RoundPersistence

    init(persistence: any RoundPersistence = UserDefaultsRoundPersistence()) {
        self.persistence = persistence
        if let savedRound = persistence.load(), savedRound.isValid {
            round = savedRound
        } else {
            round = .empty
        }
    }

    var totalStrokes: Int {
        round.holes.reduce(0) { $0 + $1.strokes.count }
    }

    func hole(number: Int) -> HoleScore {
        round.holes.first(where: { $0.id == number }) ?? HoleScore(id: number)
    }

    @discardableResult
    func addStroke(to holeNumber: Int, at timestamp: Date = Date()) -> Bool {
        guard let index = round.holes.firstIndex(where: { $0.id == holeNumber }) else {
            return false
        }

        round.holes[index].strokes.append(StrokeRecord(timestamp: timestamp))
        persist()
        return true
    }

    func resetHole(_ holeNumber: Int) {
        guard let index = round.holes.firstIndex(where: { $0.id == holeNumber }) else {
            return
        }
        round.holes[index].strokes.removeAll()
        persist()
    }

    func resetAll() {
        round = .empty
        persist()
    }

    func reload() {
        guard let savedRound = persistence.load(), savedRound.isValid else {
            return
        }
        round = savedRound
    }

    static func strokeSummary(for count: Int) -> String {
        "\(count) \(count == 1 ? "Stroke" : "Strokes")"
    }

    private func persist() {
        persistence.save(round)
    }
}
