import WidgetKit
import SwiftUI
import BugleCore

struct BugleWidgetEntry: TimelineEntry {
    let date: Date
    let locationName: String
    let report: GradeReport?
    let needsSetup: Bool
}

struct BugleWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BugleWidgetEntry {
        BugleWidgetEntry(date: Date(), locationName: "WASHINGTON", report: sampleReport, needsSetup: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (BugleWidgetEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else if let cache = SharedStore.loadCache() {
            completion(.init(date: Date(), locationName: cache.locationName, report: cache.report, needsSetup: false))
        } else {
            completion(.init(date: Date(), locationName: "BUGLE WEATHER", report: nil, needsSetup: true))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BugleWidgetEntry>) -> Void) {
        Task {
            guard let location = SharedStore.loadLocation() else {
                let entry = BugleWidgetEntry(date: Date(), locationName: "BUGLE WEATHER", report: nil, needsSetup: true)
                completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(1800))))
                return
            }

            do {
                let service = WeatherService()
                let (_, reports) = try await service.fetch(
                    latitude: location.latitude,
                    longitude: location.longitude,
                    countryCode: location.countryCode,
                    preferences: SharedStore.loadPreferences()
                )
                let report = reports.first
                if let report {
                    SharedStore.save(cache: .init(locationName: location.name, report: report, updatedAt: Date()))
                }
                let entry = BugleWidgetEntry(date: Date(), locationName: location.name, report: report, needsSetup: false)
                completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(2 * 60 * 60))))
            } catch {
                if let cache = SharedStore.loadCache() {
                    let entry = BugleWidgetEntry(date: Date(), locationName: cache.locationName, report: cache.report, needsSetup: false)
                    completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 60))))
                } else {
                    let entry = BugleWidgetEntry(date: Date(), locationName: location.name, report: nil, needsSetup: false)
                    completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 60))))
                }
            }
        }
    }

    private var sampleReport: GradeReport {
        GradeReport(
            dateKey: "2026-09-06",
            grade: .aMinus,
            verdict: "NEARLY PERFECT",
            editorial: "High 78°F with a dry, calm afternoon.",
            highF: 78,
            lowF: 59,
            factors: []
        )
    }
}

struct BugleWeatherWidgetView: View {
    let entry: BugleWidgetEntry

    var body: some View {
        if entry.needsSetup {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "sun.max")
                    .font(.title)
                Text("BUGLE WEATHER")
                    .font(.caption.weight(.black))
                    .tracking(1)
                Spacer()
                Text("Open the app once to set your location.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(4)
        } else if let report = entry.report {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.locationName.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(report.grade.display)
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)

                Text(report.verdict)
                    .font(.caption.weight(.black))
                    .lineLimit(1)

                Spacer(minLength: 2)

                Text("H \(Int(report.highF.rounded()))° · L \(Int(report.lowF.rounded()))°")
                    .font(.caption2.weight(.semibold))

                Text(report.editorial)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(3)
        } else {
            VStack(alignment: .leading) {
                Text("BUGLE WEATHER").font(.caption.weight(.black))
                Spacer()
                Text("Forecast unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct BugleWeatherWidget: Widget {
    let kind = "BugleWeatherWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BugleWidgetProvider()) { entry in
            BugleWeatherWidgetView(entry: entry)
                .containerBackground(Color(.systemBackground), for: .widget)
        }
        .configurationDisplayName("Bugle Weather")
        .description("Your weather grade for the day.")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct BugleWeatherWidgetBundle: WidgetBundle {
    var body: some Widget {
        BugleWeatherWidget()
    }
}
