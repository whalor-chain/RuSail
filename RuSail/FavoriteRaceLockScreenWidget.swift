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

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        f.locale = Locale(identifier: "ru_RU")
        return f
    }()

    private func loadEntry() -> FavoriteRaceEntry {
        let favoriteIDs = FavoritesStorage.all()
        let favorites = raceEvents2026.filter { favoriteIDs.contains($0.id) }

        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let fmt = Self.dateFormatter

        // Find nearest favorite: currently ongoing or nearest future
        let nearest = favorites
            .compactMap { event -> (RaceEvent, Date, Date)? in
                guard let start = fmt.date(from: event.startDate),
                      let end = fmt.date(from: event.endDate) else { return nil }
                return (event, start, end)
            }
            .filter { _, _, end in
                // Keep events that haven't ended yet (ongoing or future)
                calendar.startOfDay(for: end) >= today
            }
            .sorted { a, b in
                // Sort by start date; ongoing events (start <= today) come first
                a.1 < b.1
            }
            .first

        guard let (event, _, _) = nearest else {
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



