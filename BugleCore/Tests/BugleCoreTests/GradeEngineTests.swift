import XCTest
@testable import BugleCore

final class GradeEngineTests: XCTestCase {
    let engine = BugleGradeEngine()

    func testPerfectDayIsAPlus() {
        let day = makeDay(high: 72, low: 58, dew: 50, sun: 0.80, wind: 5, gust: 10)
        XCTAssertEqual(engine.grade(day: day).grade, .aPlus)
    }

    func testGoodButWarmDayIsB() {
        let day = makeDay(high: 90, low: 70, temp: 84, humidity: 30, dew: 52, sun: 0.75, wind: 5, gust: 10)
        XCTAssertEqual(engine.grade(day: day).grade, .b)
    }

    func testHotDayIsCPlus() {
        let day = makeDay(high: 94, low: 75, temp: 92, humidity: 30, dew: 55, sun: 0.75, wind: 5, gust: 10)
        XCTAssertEqual(engine.grade(day: day).grade, .cPlus)
    }

    func testStickyDayIsC() {
        let day = makeDay(high: 84, low: 72, temp: 80, humidity: 70, dew: 71, sun: 0.70, wind: 5, gust: 10)
        XCTAssertEqual(engine.grade(day: day).grade, .c)
    }

    func testBriefRainIsB() {
        let day = makeDay(high: 74, low: 60, dew: 55, sun: 0.60, wetHours: 2)
        XCTAssertEqual(engine.grade(day: day).grade, .b)
    }

    func testOnAndOffRainIsC() {
        let day = makeDay(high: 74, low: 60, dew: 55, sun: 0.55, wetHours: 5)
        XCTAssertEqual(engine.grade(day: day).grade, .c)
    }

    func testRainMostOfDayIsDPlus() {
        let day = makeDay(high: 74, low: 60, dew: 55, sun: 0.30, wetHours: 8)
        XCTAssertEqual(engine.grade(day: day).grade, .dPlus)
    }

    func testHeatIndex105IsF() {
        let day = makeDay(high: 98, low: 80, temp: 96, humidity: 60, dew: 75, sun: 0.70)
        XCTAssertEqual(engine.grade(day: day).grade, .f)
    }

    func testSunny42DegreeWinterDayIsBMinus() {
        let day = makeDay(high: 42, low: 30, temp: 40, humidity: 45, dew: 25, sun: 0.75, wind: 4, gust: 8)
        XCTAssertEqual(engine.grade(day: day).grade, .bMinus)
    }

    func testRawColdIsC() {
        let day = makeDay(high: 42, low: 34, temp: 40, humidity: 80, dew: 37, sun: 0.10, wind: 15, gust: 25, wetHours: 3)
        XCTAssertEqual(engine.grade(day: day).grade, .c)
    }

    func testFreezingRainIsDPlus() {
        var day = makeDay(high: 34, low: 29, temp: 32, humidity: 90, dew: 31, sun: 0.05, wetHours: 1)
        day = replacingCodes(day, codes: [66])
        XCTAssertEqual(engine.grade(day: day).grade, .dPlus)
    }

    func testAdvisoryCapsAtD() {
        let day = makeDay(high: 72, low: 58, dew: 50, sun: 0.80)
        let report = engine.grade(day: day, alerts: [.init(event: "Heat Advisory")])
        XCTAssertEqual(report.grade, .d)
    }

    func testWarningIsF() {
        let day = makeDay(high: 72, low: 58, dew: 50, sun: 0.80)
        let report = engine.grade(day: day, alerts: [.init(event: "Severe Thunderstorm Warning")])
        XCTAssertEqual(report.grade, .f)
    }

    func testWarmPreferenceCanImproveWarmDryDay() {
        let day = makeDay(high: 90, low: 70, temp: 84, humidity: 30, dew: 52, sun: 0.75)
        let canonical = engine.grade(day: day).grade
        let warm = engine.grade(day: day, preferences: .init(temperatureBias: 1)).grade
        XCTAssertTrue(warm > canonical)
    }

    func testHumidityToleranceCanImproveMuggyDay() {
        let day = makeDay(high: 82, low: 72, temp: 80, humidity: 68, dew: 70, sun: 0.75)
        let canonical = engine.grade(day: day).grade
        let tolerant = engine.grade(day: day, preferences: .init(humidityTolerance: 2)).grade
        XCTAssertTrue(tolerant > canonical)
    }

    // MARK: fixtures

    private func makeDay(
        high: Double,
        low: Double,
        temp: Double? = nil,
        humidity: Double = 45,
        dew: Double = 50,
        sun: Double = 0.75,
        wind: Double = 5,
        gust: Double = 10,
        wetHours: Int = 0,
        snowfallIn: Double = 0
    ) -> ForecastDay {
        let baseTemp = temp ?? min(high, 72)
        let hours: [HourlyWeather] = (8..<20).map { hour in
            let wet = hour < 8 + wetHours
            return HourlyWeather(
                localTime: String(format: "2026-09-06T%02d:00", hour),
                hour: hour,
                temperatureF: baseTemp,
                apparentTemperatureF: baseTemp,
                relativeHumidity: humidity,
                dewPointF: dew,
                precipitationProbability: wet ? 70 : 5,
                precipitationIn: wet ? 0.05 : 0,
                rainIn: wet ? 0.05 : 0,
                snowfallIn: 0,
                weatherCode: wet ? 61 : 0,
                cloudCover: sun >= 0.5 ? 20 : 85,
                windSpeedMph: wind,
                windGustMph: gust,
                isDay: true
            )
        }
        return ForecastDay(
            dateKey: "2026-09-06",
            highF: high,
            lowF: low,
            precipitationSumIn: Double(wetHours) * 0.05,
            rainSumIn: Double(wetHours) * 0.05,
            snowfallSumIn: snowfallIn,
            precipitationHours: Double(wetHours),
            sunshineDurationSeconds: 43_200 * sun,
            daylightDurationSeconds: 43_200,
            windSpeedMaxMph: wind,
            windGustMaxMph: gust,
            hourly: hours
        )
    }

    private func replacingCodes(_ day: ForecastDay, codes: [Int]) -> ForecastDay {
        let newHours = day.hourly.enumerated().map { i, h in
            HourlyWeather(
                localTime: h.localTime, hour: h.hour, temperatureF: h.temperatureF,
                apparentTemperatureF: h.apparentTemperatureF, relativeHumidity: h.relativeHumidity,
                dewPointF: h.dewPointF, precipitationProbability: h.precipitationProbability,
                precipitationIn: h.precipitationIn, rainIn: h.rainIn, snowfallIn: h.snowfallIn,
                weatherCode: i < codes.count ? codes[i] : h.weatherCode,
                cloudCover: h.cloudCover, windSpeedMph: h.windSpeedMph, windGustMph: h.windGustMph,
                isDay: h.isDay
            )
        }
        return ForecastDay(
            dateKey: day.dateKey, timezone: day.timezone, highF: day.highF, lowF: day.lowF,
            precipitationSumIn: day.precipitationSumIn, rainSumIn: day.rainSumIn,
            snowfallSumIn: day.snowfallSumIn, precipitationHours: day.precipitationHours,
            precipitationProbabilityMax: day.precipitationProbabilityMax, weatherCode: day.weatherCode,
            sunshineDurationSeconds: day.sunshineDurationSeconds, daylightDurationSeconds: day.daylightDurationSeconds,
            windSpeedMaxMph: day.windSpeedMaxMph, windGustMaxMph: day.windGustMaxMph,
            hourly: newHours
        )
    }
}
