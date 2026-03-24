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
        // Приоритет: iCloud → локальный App Group
        if let cloudIds = CloudSyncManager.shared.loadFavorites(), !cloudIds.isEmpty {
            // Обновляем локальный кеш для виджета
            sharedDefaults.set(Array(cloudIds), forKey: key)
            return cloudIds
        }
        return Set(sharedDefaults.stringArray(forKey: key) ?? [])
    }

    static func save(_ ids: Set<String>) {
        sharedDefaults.set(Array(ids), forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
        // Синхронизируем в iCloud
        CloudSyncManager.shared.saveFavorites(ids)
    }
}
