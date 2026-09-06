import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum WeatherServiceError: Error, LocalizedError {
    case invalidURL
    case badResponse(Int)
    case malformedForecast

    public var errorDescription: String? {
        switch self {
        case .invalidURL: "Could not construct the weather request."
        case .badResponse(let code): "Weather service returned HTTP \(code)."
        case .malformedForecast: "Weather service returned an incomplete forecast."
        }
    }
}

public struct OpenMeteoClient: Sendable {
    public init() {}

    public func fetchForecast(latitude: Double, longitude: Double, days: Int = 8) async throws -> ForecastBundle {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "timezone", value: "auto"),
            .init(name: "forecast_days", value: String(min(10, max(1, days)))),
            .init(name: "temperature_unit", value: "fahrenheit"),
            .init(name: "wind_speed_unit", value: "mph"),
            .init(name: "precipitation_unit", value: "inch"),
            .init(name: "hourly", value: [
                "temperature_2m", "apparent_temperature", "relative_humidity_2m", "dew_point_2m",
                "precipitation_probability", "precipitation", "rain", "snowfall", "weather_code",
                "cloud_cover", "wind_speed_10m", "wind_gusts_10m", "is_day"
            ].joined(separator: ",")),
            .init(name: "daily", value: [
                "temperature_2m_max", "temperature_2m_min", "apparent_temperature_max", "apparent_temperature_min",
                "precipitation_sum", "rain_sum", "snowfall_sum", "precipitation_hours",
                "precipitation_probability_max", "weather_code", "sunrise", "sunset",
                "sunshine_duration", "daylight_duration", "wind_speed_10m_max", "wind_gusts_10m_max"
            ].joined(separator: ","))
        ]
        guard let url = components.url else { throw WeatherServiceError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw WeatherServiceError.badResponse(http.statusCode)
        }
        let raw = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        return try raw.toBundle()
    }
}

private struct OpenMeteoResponse: Decodable {
    let latitude: Double
    let longitude: Double
    let timezone: String
    let hourly: HourlyBlock
    let daily: DailyBlock

    struct HourlyBlock: Decodable {
        let time: [String]
        let temperature: [Double?]
        let apparent: [Double?]
        let humidity: [Double?]
        let dewPoint: [Double?]
        let precipProbability: [Double?]
        let precipitation: [Double?]
        let rain: [Double?]
        let snowfall: [Double?]
        let weatherCode: [Int?]
        let cloudCover: [Double?]
        let windSpeed: [Double?]
        let windGust: [Double?]
        let isDay: [Int?]

        enum CodingKeys: String, CodingKey {
            case time
            case temperature = "temperature_2m"
            case apparent = "apparent_temperature"
            case humidity = "relative_humidity_2m"
            case dewPoint = "dew_point_2m"
            case precipProbability = "precipitation_probability"
            case precipitation, rain, snowfall
            case weatherCode = "weather_code"
            case cloudCover = "cloud_cover"
            case windSpeed = "wind_speed_10m"
            case windGust = "wind_gusts_10m"
            case isDay = "is_day"
        }
    }

    struct DailyBlock: Decodable {
        let time: [String]
        let high: [Double?]
        let low: [Double?]
        let precipitationSum: [Double?]
        let rainSum: [Double?]
        let snowfallSum: [Double?]
        let precipitationHours: [Double?]
        let precipitationProbabilityMax: [Double?]
        let weatherCode: [Int?]
        let sunshineDuration: [Double?]
        let daylightDuration: [Double?]
        let windSpeedMax: [Double?]
        let windGustMax: [Double?]

        enum CodingKeys: String, CodingKey {
            case time
            case high = "temperature_2m_max"
            case low = "temperature_2m_min"
            case precipitationSum = "precipitation_sum"
            case rainSum = "rain_sum"
            case snowfallSum = "snowfall_sum"
            case precipitationHours = "precipitation_hours"
            case precipitationProbabilityMax = "precipitation_probability_max"
            case weatherCode = "weather_code"
            case sunshineDuration = "sunshine_duration"
            case daylightDuration = "daylight_duration"
            case windSpeedMax = "wind_speed_10m_max"
            case windGustMax = "wind_gusts_10m_max"
        }
    }

    func toBundle() throws -> ForecastBundle {
        let n = hourly.time.count
        let arraysOkay = [
            hourly.temperature.count, hourly.apparent.count, hourly.humidity.count, hourly.dewPoint.count,
            hourly.precipProbability.count, hourly.precipitation.count, hourly.rain.count, hourly.snowfall.count,
            hourly.weatherCode.count, hourly.cloudCover.count, hourly.windSpeed.count, hourly.windGust.count,
            hourly.isDay.count
        ].allSatisfy { $0 == n }
        guard arraysOkay else { throw WeatherServiceError.malformedForecast }

        var byDate: [String: [HourlyWeather]] = [:]
        for i in 0..<n {
            let time = hourly.time[i]
            guard time.count >= 13 else { continue }
            let dateKey = String(time.prefix(10))
            let start = time.index(time.startIndex, offsetBy: 11)
            let end = time.index(start, offsetBy: 2)
            let hour = Int(time[start..<end]) ?? 0
            let item = HourlyWeather(
                localTime: time,
                hour: hour,
                temperatureF: hourly.temperature[i] ?? 0,
                apparentTemperatureF: hourly.apparent[i] ?? hourly.temperature[i] ?? 0,
                relativeHumidity: hourly.humidity[i] ?? 0,
                dewPointF: hourly.dewPoint[i] ?? 0,
                precipitationProbability: hourly.precipProbability[i] ?? 0,
                precipitationIn: hourly.precipitation[i] ?? 0,
                rainIn: hourly.rain[i] ?? 0,
                snowfallIn: hourly.snowfall[i] ?? 0,
                weatherCode: hourly.weatherCode[i] ?? 0,
                cloudCover: hourly.cloudCover[i] ?? 0,
                windSpeedMph: hourly.windSpeed[i] ?? 0,
                windGustMph: hourly.windGust[i] ?? 0,
                isDay: (hourly.isDay[i] ?? 0) == 1
            )
            byDate[dateKey, default: []].append(item)
        }

        let count = daily.time.count
        var days: [ForecastDay] = []
        for i in 0..<count {
            guard i < daily.high.count, i < daily.low.count else { break }
            let key = daily.time[i]
            days.append(ForecastDay(
                dateKey: key,
                timezone: timezone,
                highF: (daily.high[safe: i] ?? nil) ?? 0,
                lowF: (daily.low[safe: i] ?? nil) ?? 0,
                precipitationSumIn: (daily.precipitationSum[safe: i] ?? nil) ?? 0,
                rainSumIn: (daily.rainSum[safe: i] ?? nil) ?? 0,
                snowfallSumIn: (daily.snowfallSum[safe: i] ?? nil) ?? 0,
                precipitationHours: (daily.precipitationHours[safe: i] ?? nil) ?? 0,
                precipitationProbabilityMax: (daily.precipitationProbabilityMax[safe: i] ?? nil) ?? 0,
                weatherCode: (daily.weatherCode[safe: i] ?? nil) ?? 0,
                sunshineDurationSeconds: (daily.sunshineDuration[safe: i] ?? nil) ?? 0,
                daylightDurationSeconds: (daily.daylightDuration[safe: i] ?? nil) ?? 1,
                windSpeedMaxMph: (daily.windSpeedMax[safe: i] ?? nil) ?? 0,
                windGustMaxMph: (daily.windGustMax[safe: i] ?? nil) ?? 0,
                hourly: byDate[key] ?? []
            ))
        }
        return ForecastBundle(latitude: latitude, longitude: longitude, timezone: timezone, days: days)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
