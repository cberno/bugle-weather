import Foundation
import BugleCore

struct LocationInfo: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let name: String
    let countryCode: String?

    var id: String { "\(latitude),\(longitude),\(name)" }
}

struct CachedWidgetPayload: Codable, Equatable {
    let locationName: String
    let report: GradeReport
    let updatedAt: Date
}
