//
//  FavoritesStorage.swift
//  RuSail
//
//  Created by Станислава Гункер on 07.03.2026.
//


import Foundation
import WidgetKit

struct FavoritesStorage {
    private static let appGroupID = "group.com.yourname.rusail"
    private static let key = "favorites.raceEventIDs"

    private static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func all() -> Set<String> {
        Set(sharedDefaults.stringArray(forKey: key) ?? [])
    }

    static func save(_ ids: Set<String>) {
        sharedDefaults.set(Array(ids), forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
