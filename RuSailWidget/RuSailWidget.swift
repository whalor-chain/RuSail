import WidgetKit
import SwiftUI

// MARK: - Date Helpers

private let inputFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "dd.MM.yyyy"
    return f
}()

private let displayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ru_RU")
    f.dateFormat = "d MMM"
    return f
}()

private func formatDate(_ dateString: String) -> String {
    guard let date = inputFormatter.date(from: dateString) else { return dateString }
    return displayFormatter.string(from: date)
}

private func nextUpcomingEvent() -> RaceEvent? {
    let today = Calendar.current.startOfDay(for: Date())
    return raceEvents2026.first { event in
        guard let end = inputFormatter.date(from: event.endDate) else { return false }
        return Calendar.current.startOfDay(for: end) >= today
    }
}

// MARK: - Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> RaceEntry {
        RaceEntry(date: Date(), event: raceEvents2026.first)
    }

    func getSnapshot(in context: Context, completion: @escaping (RaceEntry) -> Void) {
        completion(RaceEntry(date: Date(), event: nextUpcomingEvent()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RaceEntry>) -> Void) {
        let entry = RaceEntry(date: Date(), event: nextUpcomingEvent())
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct RaceEntry: TimelineEntry {
    let date: Date
    let event: RaceEvent?
}

// MARK: - Widget View

struct RuSailWidgetEntryView: View {
    var entry: RaceEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let event = entry.event {
            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.system(size: family == .systemSmall ? 13 : 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text("\(formatDate(event.startDate)) – \(formatDate(event.endDate))")
                    .font(.system(size: family == .systemSmall ? 12 : 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))

                Text(event.location)
                    .font(.system(size: family == .systemSmall ? 11 : 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(2)
        } else {
            Text("Нет предстоящих регат")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

// MARK: - Widget

struct RuSailWidget: Widget {
    let kind: String = "RuSailWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            RuSailWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.black
                }
        }
        .configurationDisplayName("RuSail")
        .description("Ближайшая регата")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    RuSailWidget()
} timeline: {
    RaceEntry(date: .now, event: raceEvents2026.first)
}
