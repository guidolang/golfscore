import SwiftUI

@main
struct GolfScoreApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: RoundStore

    init() {
        if ProcessInfo.processInfo.arguments.contains("-reset-data") {
            UserDefaults.standard.removeObject(forKey: UserDefaultsRoundPersistence.storageKey)
            UserDefaultsRoundPersistence.sharedDefaults.removeObject(forKey: UserDefaultsRoundPersistence.storageKey)
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
