import Foundation

public struct WeatherService: Sendable {
    public let openMeteo: OpenMeteoClient
    public let nws: NWSAlertsClient
    public let engine: BugleGradeEngine

    public init(
        openMeteo: OpenMeteoClient = .init(),
        nws: NWSAlertsClient = .init(),
        engine: BugleGradeEngine = .init()
    ) {
        self.openMeteo = openMeteo
        self.nws = nws
        self.engine = engine
    }

    public func fetch(
        latitude: Double,
        longitude: Double,
        countryCode: String?,
        preferences: WeatherPreferences
    ) async throws -> (ForecastBundle, [GradeReport]) {
        async let forecastTask = openMeteo.fetchForecast(latitude: latitude, longitude: longitude)

        let alerts: [WeatherAlert]
        if countryCode?.uppercased() == "US" {
            alerts = (try? await nws.fetchActiveAlerts(latitude: latitude, longitude: longitude)) ?? []
        } else {
            alerts = []
        }

        let forecast = try await forecastTask
        let reports = forecast.days.enumerated().map { index, day in
            engine.grade(day: day, preferences: preferences, alerts: index == 0 ? alerts : [])
        }
        return (forecast, reports)
    }
}
