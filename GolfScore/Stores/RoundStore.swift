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

    @discardableResult
    func saveNote(_ note: String, for strokeID: UUID, in holeNumber: Int) -> Bool {
        guard let holeIndex = round.holes.firstIndex(where: { $0.id == holeNumber }),
              let strokeIndex = round.holes[holeIndex].strokes.firstIndex(where: { $0.id == strokeID }) else {
            return false
        }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        round.holes[holeIndex].strokes[strokeIndex].note = trimmedNote.isEmpty ? nil : trimmedNote
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

    nonisolated static func scorecardCSV(
        for round: RoundState,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.timeZone = timeZone
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXX"

        var rows = ["Hole,Stroke,DateTime,Note"]
        for hole in round.holes where !hole.strokes.isEmpty {
            for (strokeIndex, stroke) in hole.strokes.enumerated() {
                let fields = [
                    String(hole.id),
                    String(strokeIndex + 1),
                    dateFormatter.string(from: stroke.timestamp),
                    stroke.note ?? ""
                ]
                rows.append(fields.map(csvField).joined(separator: ","))
            }
        }
        return rows.joined(separator: "\r\n")
    }

    nonisolated private static func csvField(_ value: String) -> String {
        let normalized = value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        guard normalized.contains(",")
                || normalized.contains("\"")
                || normalized.contains("\n") else {
            return normalized
        }
        return "\"\(normalized.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private func persist() {
        persistence.save(round)
    }
}
