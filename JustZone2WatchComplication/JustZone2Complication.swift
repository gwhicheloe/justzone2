import WidgetKit
import SwiftUI

struct JustZone2ComplicationEntry: TimelineEntry {
    let date: Date
}

struct JustZone2ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> JustZone2ComplicationEntry {
        JustZone2ComplicationEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (JustZone2ComplicationEntry) -> Void) {
        completion(JustZone2ComplicationEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<JustZone2ComplicationEntry>) -> Void) {
        let entry = JustZone2ComplicationEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct JustZone2ComplicationView: View {
    @Environment(\.widgetFamily) var family
    var entry: JustZone2ComplicationEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Text("2")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
            }
        case .accessoryCorner:
            Text("2")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.green)
                .widgetLabel {
                    Text("Zone 2")
                }
        case .accessoryInline:
            Text("Zone 2")
        case .accessoryRectangular:
            HStack(spacing: 4) {
                Text("2")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                VStack(alignment: .leading) {
                    Text("JustZone2")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Tap to start")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        @unknown default:
            Text("2")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.green)
        }
    }
}

@main
struct JustZone2Complication: Widget {
    let kind = "JustZone2Complication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JustZone2ComplicationProvider()) { entry in
            JustZone2ComplicationView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("JustZone2")
        .description("Quick launch JustZone2")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
            .accessoryRectangular
        ])
    }
}
