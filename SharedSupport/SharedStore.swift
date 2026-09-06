import Foundation
import BugleCore

/// Shared by the app and widget extension through an App Group.
enum SharedStore {
    static let appGroup = "group.com.charleyberno.BugleWeather"
    private static let locationKey = "bugle.location"
    private static let preferencesKey = "bugle.preferences"
    private static let cacheKey = "bugle.widgetCache"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static func save(location: LocationInfo) {
        encode(location, key: locationKey)
    }

    static func loadLocation() -> LocationInfo? {
        decode(LocationInfo.self, key: locationKey)
    }

    static func save(preferences: WeatherPreferences) {
        encode(preferences, key: preferencesKey)
    }

    static func loadPreferences() -> WeatherPreferences {
        decode(WeatherPreferences.self, key: preferencesKey) ?? .canonical
    }

    static func save(cache: CachedWidgetPayload) {
        encode(cache, key: cacheKey)
    }

    static func loadCache() -> CachedWidgetPayload? {
        decode(CachedWidgetPayload.self, key: cacheKey)
    }

    private static func encode<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
