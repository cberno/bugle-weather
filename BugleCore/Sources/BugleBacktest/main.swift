import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import BugleCore

@main
struct BugleBacktest {
    static func main() async {
        let args = CommandLine.arguments
        let latitude = value(after: "--lat", in: args).flatMap(Double.init) ?? 38.96
        let longitude = value(after: "--lon", in: args).flatMap(Double.init) ?? -77.08
        let start = value(after: "--start", in: args) ?? "2024-01-01"
        let end = value(after: "--end", in: args) ?? "2025-12-31"

        print("Bugle Weather calibration backtest")
        print("Location: \(latitude), \(longitude)")
        print("Period: \(start) through \(end)")
        print("Note: this calibrates realized physical weather from Open-Meteo historical data; historical NWS alerts are not included.\n")

        do {
            let days = try await HistoricalOpenMeteoClient().fetch(
                latitude: latitude,
                longitude: longitude,
                startDate: start,
                endDate: end
            )
            let engine = BugleGradeEngine()
            let reports = days.map { engine.grade(day: $0) }
            printSummary(reports)
        } catch {
            fputs("Backtest failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func value(after flag: String, in args: [String]) -> String? {
        guard let i = args.firstIndex(of: flag), args.indices.contains(i + 1) else { return nil }
        return args[i + 1]
    }

    private static func printSummary(_ reports: [GradeReport]) {
        guard !reports.isEmpty else {
            print("No days returned.")
            return
        }

        let allGrades: [WeatherGrade] = [
            .aPlus, .a, .aMinus,
            .bPlus, .b, .bMinus,
            .cPlus, .c, .cMinus,
            .dPlus, .d, .dMinus,
            .f
        ]
        let counts = Dictionary(grouping: reports, by: \.grade).mapValues(\.count)
        let total = Double(reports.count)

        print("GRADE DISTRIBUTION (\(reports.count) days)")
        for grade in allGrades {
            let n = counts[grade, default: 0]
            let pct = Double(n) / total * 100
            print(String(format: "%3@  %4d  %5.1f%%", grade.display as NSString, n, pct))
        }

        func family(_ letters: Set<String>) -> Int {
            reports.filter { letters.contains(String($0.grade.display.prefix(1))) }.count
        }

        print("\nLETTER FAMILIES")
        for letter in ["A", "B", "C", "D", "F"] {
            let n = family([letter])
            print(String(format: "%@  %4d  %5.1f%%", letter, n, Double(n) / total * 100))
        }

        print("\nA+ DAYS: \(counts[.aPlus, default: 0])")
        print("F DAYS:  \(counts[.f, default: 0])")

        func driverCounts(_ selected: [GradeReport]) -> [(WeatherFactor, Int)] {
            let grouped = Dictionary(grouping: selected.compactMap { $0.primaryFactor?.factor }, by: { $0 })
                .mapValues(\.count)
            return grouped.sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key.label < rhs.key.label
            }
        }

        print("\nPRIMARY GRADE DRIVERS")
        for (factor, n) in driverCounts(reports) {
            print(String(format: "%-14@ %4d  %5.1f%%", factor.label as NSString, n, Double(n) / total * 100))
        }

        let rough = reports.filter { $0.grade <= .dPlus }
        if !rough.isEmpty {
            print("\nD/F DRIVERS (\(rough.count) days)")
            for (factor, n) in driverCounts(rough) {
                print(String(format: "%-14@ %4d  %5.1f%%", factor.label as NSString, n, Double(n) / Double(rough.count) * 100))
            }
        }

        let winterRough = rough.filter { report in
            let month = Int(report.dateKey.dropFirst(5).prefix(2)) ?? 0
            return [12, 1, 2].contains(month)
        }
        if !winterRough.isEmpty {
            print("\nWINTER D/F DRIVERS (\(winterRough.count) days)")
            for (factor, n) in driverCounts(winterRough) {
                print(String(format: "%-14@ %4d  %5.1f%%", factor.label as NSString, n, Double(n) / Double(winterRough.count) * 100))
            }
        }

        let sorted = reports.sorted {
            if $0.grade != $1.grade { return $0.grade > $1.grade }
            return $0.dateKey < $1.dateKey
        }

        print("\nTEN BEST")
        for r in sorted.prefix(10) {
            print("\(r.dateKey)  \(r.grade.display)  \(Int(r.highF.rounded()))°/\(Int(r.lowF.rounded()))°  \(r.editorial)")
        }

        print("\nTEN WORST")
        for r in sorted.suffix(10).reversed() {
            print("\(r.dateKey)  \(r.grade.display)  \(Int(r.highF.rounded()))°/\(Int(r.lowF.rounded()))°  \(r.editorial)")
        }

        let monthly = Dictionary(grouping: reports) { String($0.dateKey.prefix(7)) }
        print("\nMONTHLY LETTER MIX")
        for month in monthly.keys.sorted() {
            guard let rs = monthly[month] else { continue }
            let t = Double(rs.count)
            let groups = ["A", "B", "C", "D", "F"].map { letter -> String in
                let n = rs.filter { $0.grade.display.hasPrefix(letter) }.count
                return "\(letter) \(Int((Double(n)/t*100).rounded()))%"
            }
            print("\(month): " + groups.joined(separator: "  "))
        }
    }
}

private struct HistoricalOpenMeteoClient {
    func fetch(latitude: Double, longitude: Double, startDate: String, endDate: String) async throws -> [ForecastDay] {
        var c = URLComponents(string: "https://archive-api.open-meteo.com/v1/archive")!
        c.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "start_date", value: startDate),
            .init(name: "end_date", value: endDate),
            .init(name: "timezone", value: "auto"),
            .init(name: "temperature_unit", value: "fahrenheit"),
            .init(name: "wind_speed_unit", value: "mph"),
            .init(name: "precipitation_unit", value: "inch"),
            .init(name: "hourly", value: [
                "temperature_2m", "apparent_temperature", "relative_humidity_2m", "dew_point_2m",
                "precipitation", "rain", "snowfall", "weather_code", "cloud_cover",
                "wind_speed_10m", "wind_gusts_10m", "is_day"
            ].joined(separator: ",")),
            .init(name: "daily", value: [
                "temperature_2m_max", "temperature_2m_min",
                "precipitation_sum", "rain_sum", "snowfall_sum", "precipitation_hours",
                "weather_code", "sunshine_duration", "daylight_duration",
                "wind_speed_10m_max", "wind_gusts_10m_max"
            ].joined(separator: ","))
        ]
        guard let url = c.url else { throw BacktestError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw BacktestError.http(http.statusCode)
        }
        let raw = try JSONDecoder().decode(ArchiveResponse.self, from: data)
        return try raw.days()
    }
}

private enum BacktestError: LocalizedError {
    case invalidURL
    case http(Int)
    case malformed

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Could not construct historical-weather URL."
        case .http(let code): "Open-Meteo historical API returned HTTP \(code)."
        case .malformed: "Historical weather response was incomplete."
        }
    }
}

private struct ArchiveResponse: Decodable {
    let timezone: String
    let hourly: Hourly
    let daily: Daily

    struct Hourly: Decodable {
        let time: [String]
        let temperature: [Double?]
        let apparent: [Double?]
        let humidity: [Double?]
        let dewPoint: [Double?]
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
            case precipitation, rain, snowfall
            case weatherCode = "weather_code"
            case cloudCover = "cloud_cover"
            case windSpeed = "wind_speed_10m"
            case windGust = "wind_gusts_10m"
            case isDay = "is_day"
        }
    }

    struct Daily: Decodable {
        let time: [String]
        let high: [Double?]
        let low: [Double?]
        let precipitationSum: [Double?]
        let rainSum: [Double?]
        let snowfallSum: [Double?]
        let precipitationHours: [Double?]
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
            case weatherCode = "weather_code"
            case sunshineDuration = "sunshine_duration"
            case daylightDuration = "daylight_duration"
            case windSpeedMax = "wind_speed_10m_max"
            case windGustMax = "wind_gusts_10m_max"
        }
    }

    func days() throws -> [ForecastDay] {
        let n = hourly.time.count
        let hourlyCounts = [
            hourly.temperature.count, hourly.apparent.count, hourly.humidity.count, hourly.dewPoint.count,
            hourly.precipitation.count, hourly.rain.count, hourly.snowfall.count, hourly.weatherCode.count,
            hourly.cloudCover.count, hourly.windSpeed.count, hourly.windGust.count, hourly.isDay.count
        ]
        guard hourlyCounts.allSatisfy({ $0 == n }) else { throw BacktestError.malformed }

        var byDate: [String: [HourlyWeather]] = [:]
        for i in 0..<n {
            let time = hourly.time[i]
            guard time.count >= 13 else { continue }
            let date = String(time.prefix(10))
            let hs = time.index(time.startIndex, offsetBy: 11)
            let he = time.index(hs, offsetBy: 2)
            let hour = Int(time[hs..<he]) ?? 0
            let precip = hourly.precipitation[i] ?? 0
            let snow = hourly.snowfall[i] ?? 0

            byDate[date, default: []].append(HourlyWeather(
                localTime: time,
                hour: hour,
                temperatureF: hourly.temperature[i] ?? 0,
                apparentTemperatureF: hourly.apparent[i] ?? hourly.temperature[i] ?? 0,
                relativeHumidity: hourly.humidity[i] ?? 0,
                dewPointF: hourly.dewPoint[i] ?? 0,
                precipitationProbability: 0, // historical realized weather has no forecast probability
                precipitationIn: precip,
                rainIn: hourly.rain[i] ?? 0,
                snowfallIn: snow,
                weatherCode: hourly.weatherCode[i] ?? 0,
                cloudCover: hourly.cloudCover[i] ?? 0,
                windSpeedMph: hourly.windSpeed[i] ?? 0,
                windGustMph: hourly.windGust[i] ?? 0,
                isDay: (hourly.isDay[i] ?? 0) == 1
            ))
        }

        var out: [ForecastDay] = []
        for i in daily.time.indices {
            let key = daily.time[i]
            out.append(ForecastDay(
                dateKey: key,
                timezone: timezone,
                highF: daily.high[safe: i] ?? 0,
                lowF: daily.low[safe: i] ?? 0,
                precipitationSumIn: daily.precipitationSum[safe: i] ?? 0,
                rainSumIn: daily.rainSum[safe: i] ?? 0,
                snowfallSumIn: daily.snowfallSum[safe: i] ?? 0,
                precipitationHours: daily.precipitationHours[safe: i] ?? 0,
                precipitationProbabilityMax: 0,
                weatherCode: daily.weatherCode[safe: i] ?? 0,
                sunshineDurationSeconds: daily.sunshineDuration[safe: i] ?? 0,
                daylightDurationSeconds: daily.daylightDuration[safe: i] ?? 1,
                windSpeedMaxMph: daily.windSpeedMax[safe: i] ?? 0,
                windGustMaxMph: daily.windGustMax[safe: i] ?? 0,
                hourly: byDate[key] ?? []
            ))
        }
        return out
    }
}

private extension Array where Element == Double? {
    subscript(safe index: Int) -> Double? {
        indices.contains(index) ? self[index] ?? nil : nil
    }
}

private extension Array where Element == Int? {
    subscript(safe index: Int) -> Int? {
        indices.contains(index) ? self[index] ?? nil : nil
    }
}
