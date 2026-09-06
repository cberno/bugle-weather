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
            alertAssessment(alerts, day: day),
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

        let primary = primaryAssessment(in: assessments, overall: overall)
        let editorial = overall == .aPlus
            ? positiveEditorial(day: day, hours: hours)
            : (primary?.reason ?? "A broadly usable day.")

        return GradeReport(
            dateKey: day.dateKey,
            grade: overall,
            verdict: verdict(for: overall, primary: primary?.factor),
            editorial: editorial,
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

    private func alertAssessment(_ alerts: [WeatherAlert], day: ForecastDay) -> FactorAssessment {
        // Alerts are context, not a blunt proxy for the whole day.
        //
        // - Watch: informational only. A broad-area possibility should not tank
        //   an otherwise beautiful day.
        // - Advisory: caps at D only when it materially overlaps the usable
        //   8am–8pm day (2+ hours).
        // - Warning: F only when it overlaps the usable day at all.
        // - Statement/other products: informational only.
        //
        // If timing is unavailable, warnings/advisories fall back to the
        // conservative original Bugle behavior; watches remain informational.
        var worst: (WeatherGrade, String) = (.aPlus, "No grade-changing weather alerts.")
        var informational: [String] = []

        for alert in alerts {
            let event = alert.event.lowercased()
            let overlap = usableDayOverlapMinutes(alert: alert, day: day)
            let hasKnownTiming =
                alert.startsAt.flatMap(parseISO8601) != nil ||
                alert.endsAt.flatMap(parseISO8601) != nil
            let candidate: WeatherGrade?

            if event.contains("warning") {
                if hasKnownTiming {
                    candidate = overlap > 0 ? .f : nil
                } else {
                    candidate = .f
                }
            } else if event.contains("advisory") {
                if hasKnownTiming {
                    candidate = overlap >= 120 ? .d : nil
                } else {
                    candidate = .d
                }
            } else {
                // Watches and statements are surfaced, but the observed/forecast
                // weather itself determines the grade.
                candidate = nil
            }

            if let candidate, candidate < worst.0 {
                let timing = alertTimingPhrase(alert: alert, overlapMinutes: overlap)
                worst = (candidate, alert.event + timing + ".")
            } else if !alert.event.isEmpty {
                informational.append(alert.event + alertTimingPhrase(alert: alert, overlapMinutes: overlap))
            }
        }

        if worst.0 == .aPlus, let first = informational.first {
            return FactorAssessment(
                factor: .alerts,
                grade: .aPlus,
                reason: first + " (informational)."
            )
        }

        return FactorAssessment(factor: .alerts, grade: worst.0, reason: worst.1)
    }

    private func usableDayOverlapMinutes(alert: WeatherAlert, day: ForecastDay) -> Double {
        guard let window = usableDayWindow(for: day) else { return 0 }

        let start = alert.startsAt.flatMap(parseISO8601)
        let end = alert.endsAt.flatMap(parseISO8601)

        // NWS active alerts normally provide both. If one edge is absent, use
        // the usable-day boundary so we can still make a sensible overlap test.
        guard start != nil || end != nil else { return 0 }
        let alertStart = start ?? window.start
        let alertEnd = end ?? window.end
        guard alertEnd > alertStart else { return 0 }

        let overlapStart = max(alertStart, window.start)
        let overlapEnd = min(alertEnd, window.end)
        guard overlapEnd > overlapStart else { return 0 }
        return overlapEnd.timeIntervalSince(overlapStart) / 60
    }

    private func usableDayWindow(for day: ForecastDay) -> (start: Date, end: Date)? {
        let zone = TimeZone(identifier: day.timezone) ?? TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone

        let parts = day.dateKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }

        var startComponents = DateComponents()
        startComponents.calendar = calendar
        startComponents.timeZone = zone
        startComponents.year = parts[0]
        startComponents.month = parts[1]
        startComponents.day = parts[2]
        startComponents.hour = 8

        var endComponents = startComponents
        endComponents.hour = 20

        guard let start = calendar.date(from: startComponents),
              let end = calendar.date(from: endComponents) else { return nil }
        return (start, end)
    }

    private func parseISO8601(_ raw: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) { return date }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }

    private func alertTimingPhrase(alert: WeatherAlert, overlapMinutes: Double) -> String {
        guard alert.startsAt != nil || alert.endsAt != nil else { return "" }
        if overlapMinutes <= 0 { return " outside the daytime grading window" }
        let hours = overlapMinutes / 60
        if hours < 1.5 { return " overlapping about 1 daytime hour" }
        return " overlapping about \(Int(hours.rounded())) daytime hours"
    }

    // MARK: - Helpers


    private func primaryAssessment(in assessments: [FactorAssessment], overall: WeatherGrade) -> FactorAssessment? {
        let tied = assessments.filter { $0.grade == overall }

        // A real warning/advisory should lead the explanation. An informational
        // A+ alert should not become the headline on a beautiful day.
        if overall < .aPlus, let alert = tied.first(where: { $0.factor == .alerts }) {
            return alert
        }

        return tied.min { lhs, rhs in
            priority(lhs.factor) < priority(rhs.factor)
        }
    }

    private func positiveEditorial(day: ForecastDay, hours: [HourlyWeather]) -> String {
        let dewPoints = hours.map(\.dewPointF).sorted(by: >)
        let sustainedDew = dewPoints.isEmpty ? 50 : dewPoints[min(2, dewPoints.count - 1)]
        let maxWind = hours.map(\.windSpeedMph).max() ?? day.windSpeedMaxMph
        let sunPct = day.sunshineRatio * 100
        return "High \(whole(day.highF))°F, dry, dew point near \(whole(sustainedDew))°F, winds to \(whole(maxWind)) mph, with about \(whole(sunPct))% sunshine."
    }

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
        case .heat: 0
        case .cold: 1
        case .conditions: 2
        case .precipitation: 3
        case .temperature: 4
        case .humidity: 5
        case .wind: 6
        case .sun: 7
        case .alerts: 8
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
