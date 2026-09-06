import Foundation

public struct BugleGradeEngine: Sendable {
    public init() {}

    public func grade(
        day: ForecastDay,
        preferences: WeatherPreferences = .canonical,
        alerts: [WeatherAlert] = []
    ) -> GradeReport {
        let hours = day.usableHours.isEmpty ? day.hourly : day.usableHours

        let assessments = [
            alertAssessment(alerts),
            heatAssessment(hours),
            coldAssessment(hours),
            temperatureAssessment(day.highF, bias: preferences.temperatureBias),
            humidityAssessment(hours, tolerance: preferences.humidityTolerance),
            precipitationAssessment(day: day, hours: hours, tolerance: preferences.rainTolerance),
            conditionsAssessment(day: day, hours: hours),
            windAssessment(hours, tolerance: preferences.windTolerance),
            sunAssessment(day.sunshineRatio, preference: preferences.sunPreference)
        ]

        var overall = assessments.map(\.grade).min() ?? .b

        // A+ is meant to be scarce: truly ideal temperature, dry, genuinely sunny,
        // calm, comfortable humidity, and no hazards. If any factor is merely A,
        // the day stays A rather than being promoted by rounding.
        if overall == .aPlus && !qualifiesForAPlus(assessments) {
            overall = .a
        }

        let primary = assessments.min { lhs, rhs in
            if lhs.grade != rhs.grade { return lhs.grade < rhs.grade }
            return priority(lhs.factor) < priority(rhs.factor)
        }

        return GradeReport(
            dateKey: day.dateKey,
            grade: overall,
            verdict: verdict(for: overall, primary: primary?.factor),
            editorial: primary?.reason ?? "A broadly usable day.",
            highF: day.highF,
            lowF: day.lowF,
            factors: assessments
        )
    }

    // MARK: - Factors

    private func temperatureAssessment(_ high: Double, bias: Int) -> FactorAssessment {
        let shift = Double(max(-2, min(2, bias))) * 5.0
        let idealLow = 55.0 + shift
        let idealHigh = 85.0 + shift
        let primeLow = 65.0 + shift
        let primeHigh = 78.0 + shift
        let g: WeatherGrade

        if (primeLow...primeHigh).contains(high) { g = .aPlus }
        else if (idealLow...idealHigh).contains(high) { g = .a }
        else if high > idealHigh {
            let d = high - idealHigh
            switch d {
            case ...3: g = .aMinus
            case ...7: g = .b
            case ...9: g = .cPlus
            case ...12: g = .c
            default: g = .cMinus
            }
        } else {
            let d = idealLow - high
            switch d {
            case ...5: g = .bPlus
            case ...10: g = .b
            case ...15: g = .bMinus
            case ...20: g = .cPlus
            case ...23: g = .c
            case ...30: g = .cMinus
            case ...40: g = .dPlus
            default: g = .d
            }
        }

        return FactorAssessment(
            factor: .temperature,
            grade: g,
            reason: "High \(whole(high))°F."
        )
    }

    private func humidityAssessment(_ hours: [HourlyWeather], tolerance: Int) -> FactorAssessment {
        let points = hours.map(\.dewPointF).sorted(by: >)
        let sustained = points.isEmpty ? 50 : points[min(2, points.count - 1)]
        let shift = Double(max(-2, min(2, tolerance))) * 3.0
        let adjusted = sustained - shift
        let g: WeatherGrade
        switch adjusted {
        case ..<55: g = .aPlus
        case ..<60: g = .a
        case ..<63: g = .bPlus
        case ..<67: g = .b
        case ..<70: g = .cPlus
        case ..<73: g = .c
        default: g = .cMinus
        }
        return FactorAssessment(
            factor: .humidity,
            grade: g,
            reason: "Sustained dew point near \(whole(sustained))°F."
        )
    }

    private func precipitationAssessment(
        day: ForecastDay,
        hours: [HourlyWeather],
        tolerance: Int
    ) -> FactorAssessment {
        let wet = hours.filter(isWetHour).count
        let effective = max(0, wet - max(-2, min(2, tolerance)))
        let g: WeatherGrade
        switch effective {
        case 0: g = day.precipitationSumIn < 0.02 ? .aPlus : .a
        case 1: g = .bPlus
        case 2: g = .b
        case 3: g = .bMinus
        case 4: g = .cPlus
        case 5: g = .c
        case 6: g = .cMinus
        case 7...8: g = .dPlus
        case 9...10: g = .d
        default: g = .dMinus
        }

        let reason: String
        if wet == 0 { reason = "Dry through the usable day." }
        else if wet == 1 { reason = "One likely wet hour." }
        else { reason = "\(wet) likely wet hours from 8 AM–8 PM." }

        return FactorAssessment(factor: .precipitation, grade: g, reason: reason)
    }

    private func sunAssessment(_ ratio: Double, preference: Int) -> FactorAssessment {
        let pct = ratio * 100
        let shift = Double(max(-2, min(2, preference))) * 7.5
        let aPlus = 70 + shift
        let a = 50 + shift
        let aMinus = 35 + shift
        let bPlus = 20 + shift
        let b = 10 + shift
        let g: WeatherGrade
        if pct >= aPlus { g = .aPlus }
        else if pct >= a { g = .a }
        else if pct >= aMinus { g = .aMinus }
        else if pct >= bPlus { g = .bPlus }
        else if pct >= b { g = .b }
        else { g = .bMinus } // clouds alone never create a C/D/F day

        return FactorAssessment(
            factor: .sun,
            grade: g,
            reason: "About \(whole(pct))% of daylight is forecast as sunshine."
        )
    }

    private func windAssessment(_ hours: [HourlyWeather], tolerance: Int) -> FactorAssessment {
        let maxWind = hours.map(\.windSpeedMph).max() ?? 0
        let maxGust = hours.map(\.windGustMph).max() ?? 0
        let t = Double(max(-2, min(2, tolerance)))
        let windShift = t * 2.5
        let gustShift = t * 4.0

        func within(_ wind: Double, _ gust: Double) -> Bool {
            maxWind <= max(1, wind + windShift) && maxGust <= max(3, gust + gustShift)
        }

        let g: WeatherGrade
        if within(8, 15) { g = .aPlus }
        else if within(12, 20) { g = .a }
        else if within(16, 27) { g = .bPlus }
        else if within(20, 34) { g = .b }
        else if within(24, 39) { g = .bMinus }
        else if within(28, 44) { g = .cPlus }
        else if within(34, 50) { g = .c }
        else { g = .dPlus }

        return FactorAssessment(
            factor: .wind,
            grade: g,
            reason: "Winds to \(whole(maxWind)) mph, gusts to \(whole(maxGust)) mph."
        )
    }

    private func heatAssessment(_ hours: [HourlyWeather]) -> FactorAssessment {
        let maxHI = hours.map { ComfortMath.heatIndexF(temperatureF: $0.temperatureF, relativeHumidity: $0.relativeHumidity) }.max() ?? 70
        let g: WeatherGrade
        switch maxHI {
        case ..<95: g = .aPlus
        case ..<97: g = .cPlus
        case ..<100: g = .c
        case ..<102: g = .dPlus
        case ..<105: g = .d
        default: g = .f
        }
        let reason = maxHI >= 95 ? "Peak heat index near \(whole(maxHI))°F." : "No meaningful heat-index penalty."
        return FactorAssessment(factor: .heat, grade: g, reason: reason)
    }

    private func coldAssessment(_ hours: [HourlyWeather]) -> FactorAssessment {
        let minWC = hours.map { ComfortMath.windChillF(temperatureF: $0.temperatureF, windMph: $0.windSpeedMph) }.min() ?? 60
        let g: WeatherGrade
        switch minWC {
        case 25...: g = .aPlus
        case 20..<25: g = .cPlus
        case 10..<20: g = .c
        case 0..<10: g = .dPlus
        case -10..<0: g = .d
        default: g = .dMinus
        }
        let reason = minWC < 25 ? "Lowest daytime wind chill near \(whole(minWC))°F." : "No meaningful wind-chill penalty."
        return FactorAssessment(factor: .cold, grade: g, reason: reason)
    }

    private func conditionsAssessment(day: ForecastDay, hours: [HourlyWeather]) -> FactorAssessment {
        let codes = hours.map(\.weatherCode)
        let freezing = codes.filter { [56, 57, 66, 67].contains($0) }.count
        let heavyFreezing = codes.contains(67)
        let hailStorm = codes.contains { [96, 99].contains($0) }
        let thunder = codes.filter { $0 == 95 }.count
        let fog = codes.filter { [45, 48].contains($0) }.count
        let snowHours = codes.filter { [71, 73, 75, 77, 85, 86].contains($0) }.count
        let wetHours = hours.filter(isWetHour).count
        let maxWind = hours.map(\.windSpeedMph).max() ?? day.windSpeedMaxMph

        var candidates: [(WeatherGrade, String)] = [(.aPlus, "No disruptive weather conditions.")]

        if freezing > 0 {
            let grade: WeatherGrade = (heavyFreezing || freezing >= 3) ? .d : .dPlus
            candidates.append((grade, freezing == 1 ? "A freezing-rain or freezing-drizzle window is possible." : "Freezing precipitation is possible for several hours."))
        }
        if hailStorm {
            candidates.append((.d, "Thunderstorms with hail are forecast."))
        } else if thunder > 0 {
            candidates.append((thunder >= 3 ? .cMinus : .cPlus, thunder == 1 ? "A thunderstorm window is forecast." : "Thunderstorms are possible for several hours."))
        }
        if fog > 0 {
            candidates.append((fog >= 3 ? .cPlus : .bMinus, fog == 1 ? "A foggy hour is possible." : "Fog may linger for several hours."))
        }
        if snowHours > 0 || day.snowfallSumIn > 0.05 {
            let grade: WeatherGrade
            switch day.snowfallSumIn {
            case ..<0.5: grade = snowHours <= 2 ? .bPlus : .b
            case ..<1.5: grade = .b
            case ..<3.5: grade = .cPlus
            case ..<6.5: grade = .c
            default: grade = .dPlus
            }
            candidates.append((grade, "About \(oneDecimal(day.snowfallSumIn)) in of snow is forecast."))
        }

        // "Raw cold" from the original Bugle rubric: cold plus wet and/or windy.
        if day.highF <= 45, wetHours >= 2 || maxWind >= 12 {
            let rawGrade: WeatherGrade = (wetHours >= 2 && maxWind >= 12) ? .c : .cPlus
            candidates.append((rawGrade, "Raw cold: high \(whole(day.highF))°F with \(wetHours >= 2 ? "wet weather" : "wind")."))
        }

        let worst = candidates.min { $0.0 < $1.0 }!
        return FactorAssessment(factor: .conditions, grade: worst.0, reason: worst.1)
    }

    private func alertAssessment(_ alerts: [WeatherAlert]) -> FactorAssessment {
        var worst: (WeatherGrade, String) = (.aPlus, "No active weather alerts.")
        for alert in alerts {
            let event = alert.event.lowercased()
            let severity = (alert.severity ?? "").lowercased()
            let candidate: WeatherGrade?
            if event.contains("warning") { candidate = .f }
            else if event.contains("advisory") { candidate = .d }
            else if event.contains("watch") { candidate = .c }
            else if severity == "extreme" { candidate = .f }
            else if severity == "severe" { candidate = .d }
            else if severity == "moderate" { candidate = .c }
            else { candidate = nil }

            if let candidate, candidate < worst.0 {
                worst = (candidate, alert.event + ".")
            }
        }
        return FactorAssessment(factor: .alerts, grade: worst.0, reason: worst.1)
    }

    // MARK: - Helpers

    private func isWetHour(_ hour: HourlyWeather) -> Bool {
        hour.precipitationProbability >= 50 || hour.precipitationIn >= 0.02 || hour.snowfallIn >= 0.05
    }

    private func qualifiesForAPlus(_ factors: [FactorAssessment]) -> Bool {
        let required: Set<WeatherFactor> = [.alerts, .temperature, .humidity, .precipitation, .conditions, .wind, .sun, .heat, .cold]
        let map = Dictionary(uniqueKeysWithValues: factors.map { ($0.factor, $0.grade) })
        return required.allSatisfy { map[$0] == .aPlus }
    }

    private func priority(_ factor: WeatherFactor) -> Int {
        switch factor {
        case .alerts: 0
        case .heat: 1
        case .cold: 2
        case .conditions: 3
        case .precipitation: 4
        case .temperature: 5
        case .humidity: 6
        case .wind: 7
        case .sun: 8
        }
    }

    private func verdict(for grade: WeatherGrade, primary: WeatherFactor?) -> String {
        switch grade {
        case .aPlus: "CANCEL-PLANS WEATHER"
        case .a: "GLORIOUS"
        case .aMinus: "NEARLY PERFECT"
        case .bPlus: "VERY GOOD"
        case .b: "GOOD DAY"
        case .bMinus: "GOOD, WITH A CATCH"
        case .cPlus: factorVerdict(primary, fallback: "USABLE")
        case .c: factorVerdict(primary, fallback: "WORK AROUND IT")
        case .cMinus: factorVerdict(primary, fallback: "MARGINAL")
        case .dPlus: factorVerdict(primary, fallback: "ROUGH")
        case .d: factorVerdict(primary, fallback: "HOSTILE")
        case .dMinus: "VERY ROUGH"
        case .f: "STAY IN"
        }
    }

    private func factorVerdict(_ factor: WeatherFactor?, fallback: String) -> String {
        switch factor {
        case .heat: "HOT"
        case .cold: "BITTER COLD"
        case .humidity: "STICKY"
        case .precipitation: "WET"
        case .conditions: "MESSY"
        case .wind: "BLUSTERY"
        case .alerts: "WEATHER ALERT"
        default: fallback
        }
    }

    private func whole(_ value: Double) -> Int { Int(value.rounded()) }
    private func oneDecimal(_ value: Double) -> String { String(format: "%.1f", value) }
}
