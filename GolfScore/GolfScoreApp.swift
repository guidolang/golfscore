import SwiftUI
import UIKit

@main
struct GolfScoreApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: RoundStore
    @State private var isDeviceLocking = false
    @State private var backgroundedAt: TimeInterval?
    @State private var unlockTransitionAt: TimeInterval?
    @State private var backgroundCleanupTask: Task<Void, Never>?
    @State private var foregroundConfirmationTask: Task<Void, Never>?

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
                .onChange(of: scenePhase, initial: true) { _, newPhase in
                    if newPhase == .active {
                        if isDeviceLocking {
                            scheduleForegroundConfirmation()
                            return
                        }

                        isDeviceLocking = false
                        backgroundedAt = nil
                        unlockTransitionAt = nil
                        cancelBackgroundCleanup()
                        store.reload()
                    } else if newPhase == .inactive,
                              isDeviceLocking,
                              UIApplication.shared.isProtectedDataAvailable,
                              unlockTransitionAt == nil {
                        unlockTransitionAt = ProcessInfo.processInfo.systemUptime
                    } else if newPhase == .background {
                        foregroundConfirmationTask?.cancel()
                        foregroundConfirmationTask = nil

                        let now = ProcessInfo.processInfo.systemUptime
                        if isDeviceLocking,
                           let unlockTransitionAt,
                           now - unlockTransitionAt >= 0.1 {
                            isDeviceLocking = false
                        }
                        backgroundedAt = now
                    }
                    updateLiveActivity(for: newPhase)
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIApplication.protectedDataWillBecomeUnavailableNotification
                    )
                ) { _ in
                    let now = ProcessInfo.processInfo.systemUptime
                    let timeSinceBackground = backgroundedAt.map { now - $0 }

                    // Preserve the activity only when locking is what moves
                    // GolfScore out of the foreground. On a physical device,
                    // the lock notification can immediately follow the
                    // background transition, so use a short classification
                    // window. A later lock means the user already left the app.
                    let isLockTransition = scenePhase != .background
                        || (timeSinceBackground ?? .infinity) <= 0.25
                    guard isLockTransition else {
                        return
                    }
                    isDeviceLocking = true
                    unlockTransitionAt = nil
                    foregroundConfirmationTask?.cancel()
                    foregroundConfirmationTask = nil
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
            scheduleBackgroundCleanup(after: .milliseconds(250))
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

    private func scheduleForegroundConfirmation() {
        foregroundConfirmationTask?.cancel()
        foregroundConfirmationTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(100))
            } catch {
                return
            }

            guard scenePhase == .active,
                  UIApplication.shared.applicationState == .active else {
                return
            }

            isDeviceLocking = false
            backgroundedAt = nil
            unlockTransitionAt = nil
            cancelBackgroundCleanup()
            store.reload()
            startLiveActivity()
        }
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
