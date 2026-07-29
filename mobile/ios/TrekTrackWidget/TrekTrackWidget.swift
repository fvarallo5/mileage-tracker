// TrekTrack home-screen widget (WidgetKit).
//
// To enable on a device:
// 1. Xcode → File → New → Target → Widget Extension → "TrekTrackWidget"
// 2. Replace generated Swift with this file (or point the target at this folder)
// 3. App Groups: enable group.com.mileagetracker.mileageTracker on Runner + widget
// 4. Set deployment target ≥ iOS 16
//
// Flutter writes data via home_widget into the App Group UserDefaults.

import SwiftUI
import WidgetKit

private let appGroupId = "group.com.mileagetracker.mileageTracker"

struct TrekTrackEntry: TimelineEntry {
  let date: Date
  let status: String
  let tripLabel: String
  let todayLabel: String
  let tracking: Bool
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> TrekTrackEntry {
    TrekTrackEntry(
      date: Date(),
      status: "Ready",
      tripLabel: "Tap to open TrekTrack",
      todayLabel: "0.0 mi today",
      tracking: false
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (TrekTrackEntry) -> Void) {
    completion(loadEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<TrekTrackEntry>) -> Void) {
    let entry = loadEntry()
    completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
  }

  private func loadEntry() -> TrekTrackEntry {
    let data = UserDefaults(suiteName: appGroupId)
    return TrekTrackEntry(
      date: Date(),
      status: data?.string(forKey: "status") ?? "Ready",
      tripLabel: data?.string(forKey: "trip_label") ?? "Tap to open TrekTrack",
      todayLabel: data?.string(forKey: "today_label") ?? "0.0 mi today",
      tracking: data?.bool(forKey: "tracking") ?? false
    )
  }
}

struct TrekTrackWidgetView: View {
  var entry: TrekTrackEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text("TrekTrack")
          .font(.caption.weight(.semibold))
          .foregroundStyle(Color(red: 0.93, green: 0.95, blue: 0.97))
        Spacer()
        if entry.tracking {
          Circle()
            .fill(Color(red: 0.20, green: 0.83, blue: 0.60))
            .frame(width: 8, height: 8)
        }
      }
      Text(entry.status)
        .font(.title3.weight(.bold))
        .foregroundStyle(Color(red: 0.23, green: 0.62, blue: 1.0))
      Text(entry.tripLabel)
        .font(.subheadline)
        .foregroundStyle(Color(red: 0.93, green: 0.95, blue: 0.97))
      Text(entry.todayLabel)
        .font(.caption)
        .foregroundStyle(Color(red: 0.55, green: 0.61, blue: 0.70))
      Spacer(minLength: 0)
    }
    .padding()
    .containerBackground(for: .widget) {
      Color(red: 0.08, green: 0.11, blue: 0.17)
    }
    .widgetURL(URL(string: "mileagetracker://start-trip"))
  }
}

@main
struct TrekTrackWidget: Widget {
  let kind: String = "TrekTrackWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      TrekTrackWidgetView(entry: entry)
    }
    .configurationDisplayName("TrekTrack")
    .description("Trip status and today's business miles.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
