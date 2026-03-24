//
//  FavoritesStore.swift
//  RuSail
//
//  Created by Станислава Гункер on 08.03.2026.
//

import Foundation
import Combine
import SwiftUI

final class FavoritesStore: ObservableObject {
    @Published private(set) var ids: Set<String>

    init() {
        self.ids = FavoritesStorage.all()

        // Подписка на обновления избранного из iCloud (другое устройство)
        CloudSyncManager.shared.onFavoritesChanged = { [weak self] cloudIds in
            guard let self else { return }
            self.ids = cloudIds
            // Обновляем локальный кеш для виджета
            FavoritesStorage.save(cloudIds)
        }
    }

    func contains(_ event: RaceEvent) -> Bool {
        ids.contains(event.id)
    }

    func toggle(_ event: RaceEvent) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
            if ids.contains(event.id) {
                ids.remove(event.id)
            } else {
                ids.insert(event.id)
            }
        }

        FavoritesStorage.save(ids)
    }
}
