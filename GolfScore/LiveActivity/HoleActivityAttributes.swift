import ActivityKit

struct HoleActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var strokes: Int
    }

    let holeNumber: Int
}
