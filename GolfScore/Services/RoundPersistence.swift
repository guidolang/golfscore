import Foundation

protocol RoundPersistence {
    func load() -> RoundState?
    func save(_ round: RoundState)
}

struct UserDefaultsRoundPersistence: RoundPersistence {
    static let storageKey = "golfscore.activeRound"
    static let appGroupIdentifier = "group.com.guidolang.golfscore"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults? = nil) {
        if let defaults {
            self.defaults = defaults
        } else {
            let sharedDefaults = Self.sharedDefaults
            if sharedDefaults.data(forKey: Self.storageKey) == nil,
               let existingRound = UserDefaults.standard.data(forKey: Self.storageKey) {
                sharedDefaults.set(existingRound, forKey: Self.storageKey)
            }
            self.defaults = sharedDefaults
        }
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    func load() -> RoundState? {
        guard let data = defaults.data(forKey: Self.storageKey) else {
            return nil
        }
        return try? decoder.decode(RoundState.self, from: data)
    }

    func save(_ round: RoundState) {
        guard let data = try? encoder.encode(round) else {
            return
        }
        defaults.set(data, forKey: Self.storageKey)
    }
}
