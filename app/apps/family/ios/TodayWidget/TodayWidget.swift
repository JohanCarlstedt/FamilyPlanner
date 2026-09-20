import SwiftUI
import WidgetKit

/// Today on the home screen. The app writes the lines it has already
/// decrypted into the shared group; this only draws them, so a widget
/// process never holds a key (crypto doc §4).
private let appGroup = "group.io.github.johancarlstedt.family"

struct TodayEntry: TimelineEntry {
    let date: Date
    let title: String
    let body: String
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: Date(), title: "Family Planner", body: "")
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(read())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        // The app refreshes the widget when it syncs; this is the fallback
        // for a phone that hasn't been opened.
        let next = Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [read()], policy: .after(next)))
    }

    private func read() -> TodayEntry {
        let defaults = UserDefaults(suiteName: appGroup)
        return TodayEntry(
            date: Date(),
            title: defaults?.string(forKey: "widget.title") ?? "Family Planner",
            body: defaults?.string(forKey: "widget.body") ?? ""
        )
    }
}

struct TodayWidgetView: View {
    var entry: TodayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.title)
                .font(.caption)
                .bold()
                .lineLimit(1)
            if entry.body.isEmpty {
                Text("—").font(.footnote).foregroundStyle(.secondary)
            } else {
                Text(entry.body)
                    .font(.footnote)
                    .lineLimit(5)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayWidget", provider: TodayProvider()) { entry in
            if #available(iOS 17.0, *) {
                TodayWidgetView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
            } else {
                TodayWidgetView(entry: entry).padding()
            }
        }
        .configurationDisplayName("Today")
        .description("The next few things today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct TodayWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
    }
}
