import ActivityKit
import Foundation

@MainActor
final class HoleLiveActivityController {
    static let shared = HoleLiveActivityController()

    private init() {}

    func start(holeNumber: Int, strokes: Int) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        await endAll()

        let attributes = HoleActivityAttributes(holeNumber: holeNumber)
        let content = ActivityContent(
            state: HoleActivityAttributes.ContentState(strokes: strokes),
            staleDate: nil
        )
        _ = try? Activity.request(attributes: attributes, content: content)
    }

    func update(holeNumber: Int, strokes: Int) async {
        let content = ActivityContent(
            state: HoleActivityAttributes.ContentState(strokes: strokes),
            staleDate: nil
        )

        for activity in Activity<HoleActivityAttributes>.activities
        where activity.attributes.holeNumber == holeNumber {
            await activity.update(content)
        }
    }

    func end(holeNumber: Int) async {
        for activity in Activity<HoleActivityAttributes>.activities
        where activity.attributes.holeNumber == holeNumber {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func endAll() async {
        for activity in Activity<HoleActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
