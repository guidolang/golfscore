import ActivityKit
import Foundation
import UIKit

@MainActor
final class HoleLiveActivityController {
    static let shared = HoleLiveActivityController()

    private struct DesiredActivity: Equatable {
        let holeNumber: Int
        let strokes: Int
    }

    private var startGeneration = 0
    private var desiredActivity: DesiredActivity?

    private init() {}

    func start(holeNumber: Int, strokes: Int) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              UIApplication.shared.applicationState != .background else {
            return
        }

        let desired = DesiredActivity(holeNumber: holeNumber, strokes: strokes)
        desiredActivity = desired
        startGeneration += 1
        let generation = startGeneration

        await reconcile(desired, generation: generation)
    }

    private func reconcile(_ desired: DesiredActivity, generation: Int) async {
        guard generation == startGeneration,
              desiredActivity == desired,
              UIApplication.shared.applicationState != .background else {
            return
        }

        let activities = Activity<HoleActivityAttributes>.activities
        let matchingActivity = activities.first {
            $0.attributes.holeNumber == desired.holeNumber
                && $0.activityState == .active
        }

        for activity in activities
        where activity.activityState == .active
                && activity.id != matchingActivity?.id {
            await activity.end(nil, dismissalPolicy: .immediate)

            guard generation == startGeneration,
                  desiredActivity == desired,
                  UIApplication.shared.applicationState != .background else {
                return
            }
        }

        guard generation == startGeneration,
              desiredActivity == desired,
              UIApplication.shared.applicationState != .background else {
            return
        }

        let content = ActivityContent(
            state: HoleActivityAttributes.ContentState(strokes: desired.strokes),
            staleDate: nil
        )

        if let matchingActivity, matchingActivity.activityState == .active {
            await matchingActivity.update(content)

            if matchingActivity.activityState == .active {
                return
            }
        }

        guard generation == startGeneration,
              desiredActivity == desired,
              UIApplication.shared.applicationState != .background else {
            return
        }

        if let activeMatch = Activity<HoleActivityAttributes>.activities.first(where: {
            $0.attributes.holeNumber == desired.holeNumber
                && $0.activityState == .active
        }) {
            await activeMatch.update(content)
            return
        }

        let attributes = HoleActivityAttributes(holeNumber: desired.holeNumber)
        _ = try? Activity.request(attributes: attributes, content: content)
    }

    func update(holeNumber: Int, strokes: Int) async {
        await start(holeNumber: holeNumber, strokes: strokes)
    }

    func end(holeNumber: Int) async {
        if desiredActivity?.holeNumber == holeNumber {
            desiredActivity = nil
            startGeneration += 1
        }

        let activities = Activity<HoleActivityAttributes>.activities
        for activity in activities
        where activity.attributes.holeNumber == holeNumber {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        await restoreDesiredActivityIfNeeded()
    }

    func endAll() async {
        guard UIApplication.shared.applicationState == .background else {
            await restoreDesiredActivityIfNeeded()
            return
        }

        desiredActivity = nil
        startGeneration += 1
        let activities = Activity<HoleActivityAttributes>.activities
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        await restoreDesiredActivityIfNeeded()
    }

    private func restoreDesiredActivityIfNeeded() async {
        guard let desiredActivity,
              UIApplication.shared.applicationState != .background else {
            return
        }

        await reconcile(desiredActivity, generation: startGeneration)
    }
}
