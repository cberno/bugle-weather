import Foundation
import CoreLocation

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var location: LocationInfo?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var errorMessage: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = manager.authorizationStatus
        location = SharedStore.loadLocation()
    }

    func requestLocation() {
        authorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            errorMessage = "Location access is off. Enable it in Settings to grade your current weather."
        @unknown default:
            break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let clLocation = locations.last else { return }
        Task { @MainActor in
            let placemark = try? await geocoder.reverseGeocodeLocation(clLocation).first
            let name = placemark?.locality
                ?? placemark?.subAdministrativeArea
                ?? placemark?.administrativeArea
                ?? "Current Location"
            let info = LocationInfo(
                latitude: clLocation.coordinate.latitude,
                longitude: clLocation.coordinate.longitude,
                name: name,
                countryCode: placemark?.isoCountryCode
            )
            location = info
            errorMessage = nil
            SharedStore.save(location: info)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if location == nil {
                errorMessage = error.localizedDescription
            }
        }
    }
}
