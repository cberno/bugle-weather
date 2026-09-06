import Foundation

/// Ordered worst (F) to best (A+). F intentionally has no +/- variants.
public enum WeatherGrade: Int, Codable, CaseIterable, Comparable, Sendable {
    case f = 0
    case dMinus = 1
    case d = 2
    case dPlus = 3
    case cMinus = 4
    case c = 5
    case cPlus = 6
    case bMinus = 7
    case b = 8
    case bPlus = 9
    case aMinus = 10
    case a = 11
    case aPlus = 12

    public static func < (lhs: WeatherGrade, rhs: WeatherGrade) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var display: String {
        switch self {
        case .aPlus: "A+"
        case .a: "A"
        case .aMinus: "A−"
        case .bPlus: "B+"
        case .b: "B"
        case .bMinus: "B−"
        case .cPlus: "C+"
        case .c: "C"
        case .cMinus: "C−"
        case .dPlus: "D+"
        case .d: "D"
        case .dMinus: "D−"
        case .f: "F"
        }
    }
}

public enum WeatherFactor: String, Codable, CaseIterable, Sendable {
    case alerts
    case heat
    case cold
    case temperature
    case humidity
    case precipitation
    case conditions
    case wind
    case sun

    public var label: String {
        switch self {
        case .alerts: "Alerts"
        case .heat: "Heat"
        case .cold: "Cold"
        case .temperature: "Temperature"
        case .humidity: "Humidity"
        case .precipitation: "Precipitation"
        case .conditions: "Conditions"
        case .wind: "Wind"
        case .sun: "Sun"
        }
    }
}

public struct FactorAssessment: Codable, Equatable, Sendable {
    public let factor: WeatherFactor
    public let grade: WeatherGrade
    public let reason: String

    public init(factor: WeatherFactor, grade: WeatherGrade, reason: String) {
        self.factor = factor
        self.grade = grade
        self.reason = reason
    }
}

public struct GradeReport: Codable, Equatable, Sendable {
    public let dateKey: String
    public let grade: WeatherGrade
    public let verdict: String
    public let editorial: String
    public let highF: Double
    public let lowF: Double
    public let factors: [FactorAssessment]

    public init(
        dateKey: String,
        grade: WeatherGrade,
        verdict: String,
        editorial: String,
        highF: Double,
        lowF: Double,
        factors: [FactorAssessment]
    ) {
        self.dateKey = dateKey
        self.grade = grade
        self.verdict = verdict
        self.editorial = editorial
        self.highF = highF
        self.lowF = lowF
        self.factors = factors
    }

    public var primaryFactor: FactorAssessment? {
        factors.min { lhs, rhs in
            if lhs.grade != rhs.grade { return lhs.grade < rhs.grade }
            return GradeReport.factorPriority(lhs.factor) < GradeReport.factorPriority(rhs.factor)
        }
    }

    private static func factorPriority(_ factor: WeatherFactor) -> Int {
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
}
