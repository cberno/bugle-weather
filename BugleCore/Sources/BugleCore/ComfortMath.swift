import Foundation

public enum ComfortMath {
    /// NWS Rothfusz regression with standard low/high humidity adjustments.
    /// For conditions below the usual heat-index range, returns air temperature.
    public static func heatIndexF(temperatureF t: Double, relativeHumidity rh: Double) -> Double {
        guard t >= 80, rh >= 40 else { return t }

        let simple = 0.5 * (t + 61.0 + ((t - 68.0) * 1.2) + (rh * 0.094))
        let averaged = (simple + t) / 2.0
        guard averaged >= 80 else { return averaged }

        var hi = -42.379
            + 2.04901523 * t
            + 10.14333127 * rh
            - 0.22475541 * t * rh
            - 0.00683783 * t * t
            - 0.05481717 * rh * rh
            + 0.00122874 * t * t * rh
            + 0.00085282 * t * rh * rh
            - 0.00000199 * t * t * rh * rh

        if rh < 13, t >= 80, t <= 112 {
            let adjustment = ((13 - rh) / 4) * sqrt(max(0, (17 - abs(t - 95)) / 17))
            hi -= adjustment
        } else if rh > 85, t >= 80, t <= 87 {
            let adjustment = ((rh - 85) / 10) * ((87 - t) / 5)
            hi += adjustment
        }
        return hi
    }

    /// NWS wind chill formula. Outside its normal domain, returns air temperature.
    public static func windChillF(temperatureF t: Double, windMph v: Double) -> Double {
        guard t <= 50, v > 3 else { return t }
        let p = pow(v, 0.16)
        return 35.74 + 0.6215 * t - 35.75 * p + 0.4275 * t * p
    }
}
