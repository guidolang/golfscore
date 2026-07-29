import SwiftUI

@main
struct GolfScoreApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: RoundStore

    init() {
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains("-reset-data") {
            UserDefaults.standard.removeObject(forKey: UserDefaultsRoundPersistence.storageKey)
            UserDefaults.standard.removeObject(forKey: AppPreferenceKeys.isShowingAllHoles)
            UserDefaultsRoundPersistence.sharedDefaults.removeObject(forKey: UserDefaultsRoundPersistence.storageKey)
        }

        if arguments.contains("-ui-testing-putts-reminder") {
            var round = RoundState.empty
            let latestStroke = Date()
            round.holes[0].strokes = [
                StrokeRecord(timestamp: latestStroke.addingTimeInterval(-61)),
                StrokeRecord(timestamp: latestStroke)
            ]
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
                        store.reload()
                    }
                }
        }
    }
}
