//
//  FavoriteRaceEntry.swift
//  RuSail
//
//  Created by Станислава Гункер on 08.03.2026.
//


import WidgetKit
import SwiftUI

struct FavoriteRaceEntry: TimelineEntry {
    let date: Date
    let title: String
    let subtitle: String
    let location: String
    let hasData: Bool
}

struct FavoriteRaceProvider: TimelineProvider {
    func placeholder(in context: Context) -> FavoriteRaceEntry {
        FavoriteRaceEntry(
            date: Date(),
            title: "Избранная регата",
            subtitle: "12.03.2026 – 18.03.2026",
            location: "Санкт-Петербург",
            hasData: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FavoriteRaceEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FavoriteRaceEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> FavoriteRaceEntry {
        let favoriteIDs = FavoritesStorage.all()

        let favorites = raceEvents2026.filter { favoriteIDs.contains($0.id) }

        let sorted = favorites.sorted {
            if $0.month == $1.month {
                return $0.startDate < $1.startDate
            }
            return $0.month < $1.month
        }

        guard let event = sorted.first else {
            return FavoriteRaceEntry(
                date: Date(),
                title: "Нет избранных регат",
                subtitle: "Добавьте событие в избранное",
                location: "RuSail",
                hasData: false
            )
        }

        return FavoriteRaceEntry(
            date: Date(),
            title: event.title,
            subtitle: "\(event.startDate) – \(event.endDate)",
            location: event.location,
            hasData: true
        )
    }
}

struct FavoriteRaceRectangularView: View {
    var entry: FavoriteRaceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if entry.hasData {
                Text(entry.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)

                Text(entry.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(entry.location)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Избранное")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(entry.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)

                Text(entry.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct FavoriteRaceLockScreenWidget: Widget {
    let kind: String = "FavoriteRaceLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FavoriteRaceProvider()) { entry in
            FavoriteRaceRectangularView(entry: entry)
        }
        .configurationDisplayName("Избранная регата")
        .description("Показывает ближайшее избранное соревнование на экране блокировки.")
        .supportedFamilies([.accessoryRectangular])
    }
}



