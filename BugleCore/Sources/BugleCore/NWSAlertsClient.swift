import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct NWSAlertsClient: Sendable {
    public init() {}

    /// NWS is only queried when the caller knows the coordinate is in the U.S.
    public func fetchActiveAlerts(latitude: Double, longitude: Double) async throws -> [WeatherAlert] {
        var components = URLComponents(string: "https://api.weather.gov/alerts/active")!
        components.queryItems = [.init(name: "point", value: "\(latitude),\(longitude)")]
        guard let url = components.url else { throw WeatherServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("BugleWeather/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/geo+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw WeatherServiceError.badResponse(http.statusCode)
        }
        let raw = try JSONDecoder().decode(NWSResponse.self, from: data)
        return raw.features.map {
            WeatherAlert(event: $0.properties.event, headline: $0.properties.headline ?? "", severity: $0.properties.severity)
        }
    }
}

private struct NWSResponse: Decodable {
    let features: [Feature]
    struct Feature: Decodable {
        let properties: Properties
    }
    struct Properties: Decodable {
        let event: String
        let headline: String?
        let severity: String?
    }
}
