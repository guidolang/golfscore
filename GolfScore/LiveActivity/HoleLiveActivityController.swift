import ActivityKit
import Foundation
import UIKit

@MainActor
final class HoleLiveActivityController {
    static let shared = HoleLiveActivityController()

    private var startGeneration = 0

    private init() {}

    func start(holeNumber: Int, strokes: Int) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              UIApplication.shared.applicationState == .active else {
            return
        }

        startGeneration += 1
        let generation = startGeneration

        let activities = Activity<HoleActivityAttributes>.activities
        let matchingActivity = activities.first {
            $0.attributes.holeNumber == holeNumber
        }

        for activity in activities where activity.id != matchingActivity?.id {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        guard generation == startGeneration,
              UIApplication.shared.applicationState == .active else {
            return
        }

        let content = ActivityContent(
            state: HoleActivityAttributes.ContentState(strokes: strokes),
            staleDate: nil
        )

        if let matchingActivity {
            await matchingActivity.update(content)
        } else {
            let attributes = HoleActivityAttributes(holeNumber: holeNumber)
            _ = try? Activity.request(attributes: attributes, content: content)
        }
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

    func endAll() async {
        startGeneration += 1
        await endAllActivities()
    }

    private func endAllActivities() async {
        for activity in Activity<HoleActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
