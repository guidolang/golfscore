import Foundation

struct StrokeRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let timestamp: Date

    init(id: UUID = UUID(), timestamp: Date = Date()) {
        self.id = id
        self.timestamp = timestamp
    }
}

struct HoleScore: Codable, Equatable, Identifiable {
    let id: Int
    var strokes: [StrokeRecord]

    init(id: Int, strokes: [StrokeRecord] = []) {
        self.id = id
        self.strokes = strokes
    }
}

struct RoundState: Codable, Equatable {
    var holes: [HoleScore]

    static let holeNumbers = Array(1...18)

    static var empty: RoundState {
        RoundState(holes: holeNumbers.map { HoleScore(id: $0) })
    }

    var isValid: Bool {
        holes.count == Self.holeNumbers.count
            && holes.map(\.id) == Self.holeNumbers
    }
}
