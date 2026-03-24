//
//  CloudSyncManager.swift
//  RuSail
//

import Foundation
import Combine

/// Синхронизация key-value данных через iCloud (NSUbiquitousKeyValueStore).
/// Работает для: избранное, профиль (ВФПС ID и т.д.).
final class CloudSyncManager {
    static let shared = CloudSyncManager()

    private let cloud = NSUbiquitousKeyValueStore.default
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Keys
    enum Key {
        static let favorites = "sync.favorites"
        static let vfpsID = "sync.vfpsID"
        static let username = "sync.username"
        static let ruSailID = "sync.ruSailID"
        static let joinedAt = "sync.joinedAt"
    }

    private init() {
        // Запускаем синхронизацию
        cloud.synchronize()

        // Подписываемся на изменения из iCloud (другие устройства)
        NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: cloud)
            .sink { [weak self] notification in
                self?.handleCloudChange(notification)
            }
            .store(in: &cancellables)
    }

    // MARK: - Favorites

    func saveFavorites(_ ids: Set<String>) {
        cloud.set(Array(ids), forKey: Key.favorites)
        cloud.synchronize()
    }

    func loadFavorites() -> Set<String>? {
        guard let arr = cloud.array(forKey: Key.favorites) as? [String] else { return nil }
        return Set(arr)
    }

    // MARK: - Profile

    func saveProfile(vfpsID: String, username: String, ruSailID: String, joinedAt: String) {
        cloud.set(vfpsID, forKey: Key.vfpsID)
        cloud.set(username, forKey: Key.username)
        cloud.set(ruSailID, forKey: Key.ruSailID)
        cloud.set(joinedAt, forKey: Key.joinedAt)
        cloud.synchronize()
    }

    func loadProfileValue(for key: String) -> String? {
        cloud.string(forKey: key)
    }

    // MARK: - Change handler

    /// Колбэк для уведомления UI об изменениях из облака
    var onFavoritesChanged: ((Set<String>) -> Void)?
    var onProfileChanged: ((_ key: String, _ value: String) -> Void)?

    private func handleCloudChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int,
              (reason == NSUbiquitousKeyValueStoreServerChange || reason == NSUbiquitousKeyValueStoreInitialSyncChange),
              let keys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
        else { return }

        for key in keys {
            switch key {
            case Key.favorites:
                if let ids = loadFavorites() {
                    DispatchQueue.main.async { self.onFavoritesChanged?(ids) }
                }
            case Key.vfpsID, Key.username, Key.ruSailID, Key.joinedAt:
                if let value = cloud.string(forKey: key) {
                    DispatchQueue.main.async { self.onProfileChanged?(key, value) }
                }
            default:
                break
            }
        }
    }
}
