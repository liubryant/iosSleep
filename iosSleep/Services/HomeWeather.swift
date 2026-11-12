import CoreLocation
import SwiftUI

@MainActor
final class HomeWeather: NSObject, ObservableObject {
    @Published private(set) var current: Conditions?
    @Published private(set) var authorization: CLAuthorizationStatus = .notDetermined

    private let locationManager = CLLocationManager()
    private let endpoint: URL?
    private static let cacheKey = "homeWeather.lastConditions"
    private var isLocating = false
    private var fetchTask: Task<Void, Never>?

    var isAvailable: Bool { endpoint != nil }

    override init() {
        endpoint = Self.forecastEndpoint()
        super.init()
        authorization = locationManager.authorizationStatus
        restoreCachedConditions()
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.delegate = self
    }

    func refresh() {
        guard canUseLocation,
              !isLocating, fetchTask == nil else { return }
        restoreCachedConditions()
        isLocating = true
        locationManager.requestLocation()
    }

    private var canUseLocation: Bool {
        isAvailable && ConsentStore.agreementAccepted
            && (authorization == .authorizedWhenInUse || authorization == .authorizedAlways)
    }

    private func restoreCachedConditions() {
        guard canUseLocation, current == nil,
              let data = UserDefaults.standard.data(forKey: Self.cacheKey),
              let cached = try? JSONDecoder().decode(Conditions.self, from: data),
              cached.temperature.isFinite else { return }
        current = cached
    }

    private func updateConditions(_ conditions: Conditions) {
        guard canUseLocation, conditions.temperature.isFinite else { return }
        if let current,
           current.temperatureText == conditions.temperatureText,
           current.appearance.symbol == conditions.appearance.symbol,
           current.appearance.description == conditions.appearance.description { return }
        if let data = try? JSONEncoder().encode(conditions) {
            UserDefaults.standard.set(data, forKey: Self.cacheKey)
        }
        current = conditions
    }

    func requestAccess() {
        guard isAvailable, ConsentStore.agreementAccepted, authorization == .notDetermined else { return }
        locationManager.requestWhenInUseAuthorization()
    }

    private static func forecastEndpoint() -> URL? {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "OpenMeteoForecastURL") as? String,
           let url = URL(string: configured), url.scheme == "https", url.host != nil {
            return url
        }
        #if DEBUG
        return URL(string: "https://api.open-meteo.com/v1/forecast")
        #else
        return nil
        #endif
    }

    private func fetch(at coordinate: CLLocationCoordinate2D) {
        guard fetchTask == nil, let endpoint,
              var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else { return }
        let latitude = (coordinate.latitude * 100).rounded() / 100
        let longitude = (coordinate.longitude * 100).rounded() / 100
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "temperature_unit", value: "celsius")
        ]
        guard let url = components.url else { return }
        fetchTask = Task { [weak self] in
            defer { self?.fetchTask = nil }
            do {
                let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return }
                let forecast = try JSONDecoder().decode(Forecast.self, from: data)
                guard !Task.isCancelled else { return }
                self?.updateConditions(forecast.current)
            } catch {
                // A transient failure leaves the last successful reading visible.
            }
        }
    }

    private struct Forecast: Decodable {
        let current: Conditions
    }

    struct Conditions: Codable {
        let temperature: Double
        let code: Int
        let isDay: Int

        enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case code = "weather_code"
            case isDay = "is_day"
        }

        var temperatureText: String {
            temperature.formatted(.number.precision(.fractionLength(0)))
        }

        var appearance: (symbol: String, tint: Color, description: String) {
            let sun = Color(red: 0.96, green: 0.66, blue: 0.14)
            let rain = Color(red: 0.18, green: 0.53, blue: 0.90)
            let snow = Color(red: 0.20, green: 0.70, blue: 0.78)
            switch code {
            case 0: return (isDay == 1 ? "sun.max.fill" : "moon.stars.fill", sun, "晴")
            case 1, 2: return (isDay == 1 ? "cloud.sun.fill" : "cloud.moon.fill", .orange, "多云")
            case 3: return ("cloud.fill", .gray, "阴")
            case 45, 48: return ("cloud.fog.fill", .gray, "雾")
            case 51, 53, 55: return ("cloud.drizzle.fill", rain, "毛毛雨")
            case 56, 57, 66, 67: return ("cloud.sleet.fill", rain, "冻雨")
            case 61, 63, 80, 81: return ("cloud.rain.fill", rain, "降雨")
            case 65, 82: return ("cloud.heavyrain.fill", rain, "强降雨")
            case 71, 73, 75, 77, 85, 86: return ("cloud.snow.fill", snow, "降雪")
            case 95: return ("cloud.bolt.rain.fill", Color(red: 0.48, green: 0.52, blue: 0.88), "雷雨")
            case 96, 99: return ("cloud.hail.fill", Color(red: 0.34, green: 0.64, blue: 0.94), "雷雨伴冰雹")
            default: return ("cloud.fill", .gray, "天气")
            }
        }
    }
}

extension HomeWeather: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        switch authorization {
        case .authorizedAlways, .authorizedWhenInUse:
            refresh()
        default:
            isLocating = false
            fetchTask?.cancel()
            current = nil
            if authorization == .denied || authorization == .restricted {
                UserDefaults.standard.removeObject(forKey: Self.cacheKey)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        isLocating = false
        guard canUseLocation,
              let location = locations.last, location.horizontalAccuracy >= 0,
              CLLocationCoordinate2DIsValid(location.coordinate) else { return }
        fetch(at: location.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocating = false
    }
}
