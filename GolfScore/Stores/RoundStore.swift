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

    @discardableResult
    func deleteStroke(from holeNumber: Int, id strokeID: UUID) -> Bool {
        guard let holeIndex = round.holes.firstIndex(where: { $0.id == holeNumber }),
              let strokeIndex = round.holes[holeIndex].strokes.firstIndex(where: { $0.id == strokeID }) else {
            return false
        }

        round.holes[holeIndex].strokes.remove(at: strokeIndex)
        persist()
        return true
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
