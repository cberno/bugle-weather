import Foundation
import WidgetKit
import BugleCore

@MainActor
final class WeatherViewModel: ObservableObject {
    @Published private(set) var reports: [GradeReport] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?

    private let service = WeatherService()

    var today: GradeReport? { reports.first }

    func load(location: LocationInfo, preferences: WeatherPreferences) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let (_, newReports) = try await service.fetch(
                latitude: location.latitude,
                longitude: location.longitude,
                countryCode: location.countryCode,
                preferences: preferences
            )
            reports = newReports
            lastUpdated = Date()
            if let today = newReports.first {
                SharedStore.save(cache: .init(locationName: location.name, report: today, updatedAt: Date()))
            }
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            errorMessage = error.localizedDescription
            if reports.isEmpty, let cached = SharedStore.loadCache() {
                reports = [cached.report]
            }
        }
    }
}
