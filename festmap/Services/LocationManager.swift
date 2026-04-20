import Foundation
import Combine
import CoreLocation

final class LocationManager: NSObject, ObservableObject {
    @Published var lastLocation: CLLocationCoordinate2D? = nil
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String? = nil

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    /// 요청: UI에서 사용자 조작으로만 호출하세요.
    /// 시스템 권한 프롬프트는 UI 주도 시점에서 띄우는 것이 안전합니다.
    func requestPermission() {
        let status = manager.authorizationStatus
        guard status == .notDetermined else { return }

        // Ensure prompt is presented from main thread to avoid UI issues.
        DispatchQueue.main.async { [weak self] in
            self?.manager.requestWhenInUseAuthorization()
        }
    }

    /// 위치 업데이트 시작: 권한 상태에 따라 동작합니다.
    /// 권한이 결정되지 않았다면 UI에서 `requestPermission()`을 호출하고
    /// delegate 콜백(`locationManagerDidChangeAuthorization`)을 기다리세요.
    func startUpdating() {
        guard CLLocationManager.locationServicesEnabled() else {
            locationError = "Location services disabled"
            return
        }

        let status = manager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .notDetermined:
            // Do not automatically prompt here; defer to UI-driven requestPermission()
            locationError = "Location permission not determined"
        default:
            locationError = "Location permission denied or restricted"
        }
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.lastLocation = nil
            }
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        DispatchQueue.main.async {
            self.lastLocation = loc.coordinate
            self.locationError = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = error.localizedDescription
        }
    }
}
