import Foundation
import Combine

@MainActor
final class WeatherViewModel: ObservableObject {
    @Published var weather: WeatherData?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let api: WeatherAPI

    init(api: WeatherAPI = OpenMeteoWeatherAPI()) {
        self.api = api
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // For now, use a default location (Ann Arbor, MI). Later: inject CoreLocation.
        let latitude = 42.2808
        let longitude = -83.7430

        do {
            let w = try await api.fetchWeather(latitude: latitude, longitude: longitude)
            self.weather = w
        } catch {
            self.errorMessage = "Unable to fetch weather."
        }
    }
}


