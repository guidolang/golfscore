import ActivityKit
import AppIntents
import AudioToolbox
import Foundation

struct AddStrokeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Add Stroke"

    @Parameter(title: "Hole Number")
    var holeNumber: Int

    @Parameter(title: "Activity ID")
    var activityID: String

    init() {}

    init(holeNumber: Int, activityID: String) {
        self.holeNumber = holeNumber
        self.activityID = activityID
    }

    func perform() async throws -> some IntentResult {
        let persistence = UserDefaultsRoundPersistence()
        var round = persistence.load() ?? .empty

        guard round.isValid,
              let index = round.holes.firstIndex(where: { $0.id == holeNumber }),
              round.holes[index].strokes.count < ScoreRules.maximumStrokesPerHole else {
            return .result()
        }

        round.holes[index].strokes.append(StrokeRecord())
        persistence.save(round)
        AudioServicesPlaySystemSoundWithCompletion(kSystemSoundID_Vibrate, nil)

        let strokes = round.holes[index].strokes.count
        let content = ActivityContent(
            state: HoleActivityAttributes.ContentState(strokes: strokes),
            staleDate: nil
        )
        let activities = Activity<HoleActivityAttributes>.activities
        if let activity = activities.first(where: { $0.id == activityID }) {
            await activity.update(content)
        } else {
            for activity in activities where activity.attributes.holeNumber == holeNumber {
                await activity.update(content)
            }
        }

        return .result()
    }
}
