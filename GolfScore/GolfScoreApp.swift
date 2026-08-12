import SwiftUI
import UIKit

@main
struct GolfScoreApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: RoundStore
    @State private var isDeviceLocking = false
    @State private var backgroundCleanupTask: Task<Void, Never>?

    init() {
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains("-reset-data") {
            UserDefaults.standard.removeObject(forKey: UserDefaultsRoundPersistence.storageKey)
            UserDefaults.standard.removeObject(forKey: AppPreferenceKeys.selectedHoleNumber)
            UserDefaultsRoundPersistence.sharedDefaults.removeObject(forKey: UserDefaultsRoundPersistence.storageKey)
        }

        if arguments.contains("-ui-testing-putts-reminder") {
            var round = RoundState.empty
            let latestStroke = Date()
            for index in 0...1 {
                round.holes[index].strokes = [
                    StrokeRecord(timestamp: latestStroke.addingTimeInterval(-61)),
                    StrokeRecord(timestamp: latestStroke)
                ]
            }
            UserDefaultsRoundPersistence().save(round)
        }

        if arguments.contains("-ui-testing-scorecard") {
            var round = RoundState.empty
            round.holes[0].strokes = [StrokeRecord(), StrokeRecord()]
            round.holes[9].strokes = [StrokeRecord(), StrokeRecord(), StrokeRecord()]
            UserDefaultsRoundPersistence().save(round)
        }

        _store = State(initialValue: RoundStore())
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        isDeviceLocking = false
                        cancelBackgroundCleanup()
                        store.reload()
                    }
                    updateLiveActivity(for: newPhase)
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIApplication.protectedDataWillBecomeUnavailableNotification
                    )
                ) { _ in
                    isDeviceLocking = true
                    cancelBackgroundCleanup()
                }
        }
    }

    private func updateLiveActivity(for scenePhase: ScenePhase) {
        if scenePhase == .inactive {
            scheduleBackgroundCleanup(after: .milliseconds(750))
            return
        }

        if scenePhase == .background {
            // Locking and switching apps both transition through background.
            // Give the protected-data notification time to identify a lock
            // before ending the activity for a genuine app-background event.
            scheduleBackgroundCleanup(after: .seconds(1))
            return
        }

        guard scenePhase == .active else {
            return
        }

        startLiveActivity()
    }

    private func scheduleBackgroundCleanup(after delay: Duration) {
        backgroundCleanupTask?.cancel()
        backgroundCleanupTask = Task { @MainActor in
            let application = UIApplication.shared
            let taskIdentifier = application.beginBackgroundTask(
                withName: "Live Activity Cleanup",
                expirationHandler: nil
            )
            defer {
                if taskIdentifier != .invalid {
                    application.endBackgroundTask(taskIdentifier)
                }
            }

            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }

            guard scenePhase == .background,
                  application.applicationState == .background,
                  !isDeviceLocking else {
                return
            }
            await HoleLiveActivityController.shared.endAll()
        }
    }

    private func cancelBackgroundCleanup() {
        backgroundCleanupTask?.cancel()
        backgroundCleanupTask = nil
    }

    private func startLiveActivity() {
        Task {
            let savedHoleNumber = UserDefaults.standard.integer(
                forKey: AppPreferenceKeys.selectedHoleNumber
            )
            let holeNumber = RoundState.holeNumbers.contains(savedHoleNumber)
                ? savedHoleNumber
                : 1
            await HoleLiveActivityController.shared.start(
                holeNumber: holeNumber,
                strokes: store.hole(number: holeNumber).strokes.count
            )
        }
    }
}
