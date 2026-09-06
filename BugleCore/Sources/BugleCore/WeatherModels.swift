import Foundation

public struct WeatherPreferences: Codable, Equatable, Sendable {
    /// -2 = cooler, +2 = warmer. Shifts the whole comfort curve by 5°F per step.
    public var temperatureBias: Int
    /// -2 = wants crisp air, +2 = tolerant of muggy air.
    public var humidityTolerance: Int
    /// -2 = hates rain, +2 = doesn't mind rain.
    public var rainTolerance: Int
    /// -2 = clouds are fine, +2 = strongly prefers sun.
    public var sunPreference: Int
    /// -2 = prefers still air, +2 = tolerant of breeze/wind.
    public var windTolerance: Int

    public init(
        temperatureBias: Int = 0,
        humidityTolerance: Int = 0,
        rainTolerance: Int = 0,
        sunPreference: Int = 0,
        windTolerance: Int = 0
    ) {
        self.temperatureBias = Self.clamp(temperatureBias)
        self.humidityTolerance = Self.clamp(humidityTolerance)
        self.rainTolerance = Self.clamp(rainTolerance)
        self.sunPreference = Self.clamp(sunPreference)
        self.windTolerance = Self.clamp(windTolerance)
    }

    public static let canonical = WeatherPreferences()

    private static func clamp(_ value: Int) -> Int { min(2, max(-2, value)) }
}

public struct HourlyWeather: Codable, Equatable, Sendable {
    public let localTime: String
    public let hour: Int
    public let temperatureF: Double
    public let apparentTemperatureF: Double
    public let relativeHumidity: Double
    public let dewPointF: Double
    public let precipitationProbability: Double
    public let precipitationIn: Double
    public let rainIn: Double
    public let snowfallIn: Double
    public let weatherCode: Int
    public let cloudCover: Double
    public let windSpeedMph: Double
    public let windGustMph: Double
    public let isDay: Bool

    public init(
        localTime: String,
        hour: Int,
        temperatureF: Double,
        apparentTemperatureF: Double,
        relativeHumidity: Double,
        dewPointF: Double,
        precipitationProbability: Double,
        precipitationIn: Double,
        rainIn: Double,
        snowfallIn: Double,
        weatherCode: Int,
        cloudCover: Double,
        windSpeedMph: Double,
        windGustMph: Double,
        isDay: Bool
    ) {
        self.localTime = localTime
        self.hour = hour
        self.temperatureF = temperatureF
        self.apparentTemperatureF = apparentTemperatureF
        self.relativeHumidity = relativeHumidity
        self.dewPointF = dewPointF
        self.precipitationProbability = precipitationProbability
        self.precipitationIn = precipitationIn
        self.rainIn = rainIn
        self.snowfallIn = snowfallIn
        self.weatherCode = weatherCode
        self.cloudCover = cloudCover
        self.windSpeedMph = windSpeedMph
        self.windGustMph = windGustMph
        self.isDay = isDay
    }
}

public struct ForecastDay: Codable, Equatable, Sendable {
    public let dateKey: String
    public let timezone: String
    public let highF: Double
    public let lowF: Double
    public let precipitationSumIn: Double
    public let rainSumIn: Double
    public let snowfallSumIn: Double
    public let precipitationHours: Double
    public let precipitationProbabilityMax: Double
    public let weatherCode: Int
    public let sunshineDurationSeconds: Double
    public let daylightDurationSeconds: Double
    public let windSpeedMaxMph: Double
    public let windGustMaxMph: Double
    public let hourly: [HourlyWeather]

    public init(
        dateKey: String,
        timezone: String = "UTC",
        highF: Double,
        lowF: Double,
        precipitationSumIn: Double = 0,
        rainSumIn: Double = 0,
        snowfallSumIn: Double = 0,
        precipitationHours: Double = 0,
        precipitationProbabilityMax: Double = 0,
        weatherCode: Int = 0,
        sunshineDurationSeconds: Double = 28_800,
        daylightDurationSeconds: Double = 43_200,
        windSpeedMaxMph: Double = 5,
        windGustMaxMph: Double = 10,
        hourly: [HourlyWeather]
    ) {
        self.dateKey = dateKey
        self.timezone = timezone
        self.highF = highF
        self.lowF = lowF
        self.precipitationSumIn = precipitationSumIn
        self.rainSumIn = rainSumIn
        self.snowfallSumIn = snowfallSumIn
        self.precipitationHours = precipitationHours
        self.precipitationProbabilityMax = precipitationProbabilityMax
        self.weatherCode = weatherCode
        self.sunshineDurationSeconds = sunshineDurationSeconds
        self.daylightDurationSeconds = daylightDurationSeconds
        self.windSpeedMaxMph = windSpeedMaxMph
        self.windGustMaxMph = windGustMaxMph
        self.hourly = hourly
    }

    public var usableHours: [HourlyWeather] {
        hourly.filter { (8..<20).contains($0.hour) }
    }

    public var sunshineRatio: Double {
        guard daylightDurationSeconds > 0 else { return 0 }
        return min(1, max(0, sunshineDurationSeconds / daylightDurationSeconds))
    }
}

public struct WeatherAlert: Codable, Equatable, Sendable {
    public let event: String
    public let headline: String
    public let severity: String?

    public init(event: String, headline: String = "", severity: String? = nil) {
        self.event = event
        self.headline = headline
        self.severity = severity
    }
}

public struct ForecastBundle: Codable, Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let timezone: String
    public let days: [ForecastDay]

    public init(latitude: Double, longitude: Double, timezone: String, days: [ForecastDay]) {
        self.latitude = latitude
        self.longitude = longitude
        self.timezone = timezone
        self.days = days
    }
}
