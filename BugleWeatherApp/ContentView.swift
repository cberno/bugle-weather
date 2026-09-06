import SwiftUI
import BugleCore

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var weather = WeatherViewModel()
    @State private var preferences = SharedStore.loadPreferences()
    @State private var showingPreferences = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    if let report = weather.today, let location = locationManager.location {
                        TodayGradeCard(report: report, locationName: location.name)
                        if weather.reports.count > 1 {
                            ForecastStrip(reports: Array(weather.reports.prefix(8)))
                        }
                        FactorBreakdown(report: report)
                    } else if weather.isLoading {
                        ProgressView("Grading the day…")
                            .frame(maxWidth: .infinity, minHeight: 280)
                    } else {
                        EmptyState(message: locationManager.errorMessage ?? weather.errorMessage)
                    }
                }
                .padding()
            }
            .refreshable { await refresh() }
            .navigationTitle("Bugle Weather")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        locationManager.requestLocation()
                    } label: {
                        Image(systemName: "location")
                    }
                    .accessibilityLabel("Refresh location")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingPreferences = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Weather preferences")
                }
            }
            .sheet(isPresented: $showingPreferences) {
                PreferencesView(preferences: preferences) { newPreferences in
                    preferences = newPreferences
                    SharedStore.save(preferences: newPreferences)
                    Task { await refresh() }
                }
            }
            .task(id: locationManager.location?.id) {
                guard let location = locationManager.location else {
                    locationManager.requestLocation()
                    return
                }
                await weather.load(location: location, preferences: preferences)
            }
        }
    }

    private func refresh() async {
        if let location = locationManager.location {
            await weather.load(location: location, preferences: preferences)
        } else {
            locationManager.requestLocation()
        }
    }
}

private struct TodayGradeCard: View {
    let report: GradeReport
    let locationName: String

    var body: some View {
        VStack(spacing: 8) {
            Text(locationName.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(.secondary)

            Text(report.grade.display)
                .font(.system(size: 92, weight: .black, design: .rounded))
                .minimumScaleFactor(0.7)

            Text(report.verdict)
                .font(.title3.weight(.heavy))
                .tracking(0.5)

            Text("H \(Int(report.highF.rounded()))°  ·  L \(Int(report.lowF.rounded()))°")
                .font(.headline)

            Text(report.editorial)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct ForecastStrip: View {
    let reports: [GradeReport]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(reports.indices, id: \.self) { index in
                    let report = reports[index]
                    VStack(spacing: 6) {
                        Text(index == 0 ? "TODAY" : shortDay(report.dateKey))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(report.grade.display)
                            .font(.title2.weight(.black))
                        Text("\(Int(report.highF.rounded()))° / \(Int(report.lowF.rounded()))°")
                            .font(.caption)
                    }
                    .frame(width: 72, height: 88)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private func shortDay(_ dateKey: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: dateKey) else { return dateKey }
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
}

private struct FactorBreakdown: View {
    let report: GradeReport

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Why \(report.grade.display)?")
                .font(.title3.weight(.bold))

            ForEach(report.factors, id: \.factor) { factor in
                HStack(alignment: .top, spacing: 12) {
                    Text(factor.grade.display)
                        .font(.headline.weight(.black))
                        .frame(width: 32, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(factor.factor.label)
                            .font(.subheadline.weight(.semibold))
                        Text(factor.reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct EmptyState: View {
    let message: String?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "location.circle")
                .font(.system(size: 48))
            Text("Bugle Weather needs your location")
                .font(.title3.weight(.bold))
            Text(message ?? "Allow location access, then Bugle Weather will grade the day wherever you are in the world.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}
