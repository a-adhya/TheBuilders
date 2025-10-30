import Foundation

// MARK: - Models

struct WeatherData: Equatable {
    let condition: String
    let temperatureF: Int
    let feelsLikeF: Int
    let lowF: Int
    let highF: Int
    let windMph: Int
    let humidityPct: Int
    let sunset: String
    let moonPhase: String
}

// MARK: - Protocol

protocol WeatherAPI {
    func fetchWeather(latitude: Double, longitude: Double) async throws -> WeatherData
}

// MARK: - Open‑Meteo implementation (no API key required)

final class OpenMeteoWeatherAPI: WeatherAPI {
    func fetchWeather(latitude: Double, longitude: Double) async throws -> WeatherData {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,relative_humidity_2m,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min,sunset&temperature_unit=fahrenheit&wind_speed_unit=mph&timezone=auto"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }

        struct APIResponse: Decodable {
            struct Current: Decodable { let temperature_2m: Double; let relative_humidity_2m: Double; let wind_speed_10m: Double }
            struct Daily: Decodable { let temperature_2m_max: [Double]; let temperature_2m_min: [Double]; let sunset: [String] }
            let current: Current
            let daily: Daily
        }

        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)

        let tempF = Int(decoded.current.temperature_2m.rounded())
        let feelsF = tempF // Open‑Meteo lacks feels like; approximate with temp
        let humidity = Int(decoded.current.relative_humidity_2m.rounded())
        let wind = Int(decoded.current.wind_speed_10m.rounded())
        let high = Int((decoded.daily.temperature_2m_max.first ?? decoded.current.temperature_2m).rounded())
        let low = Int((decoded.daily.temperature_2m_min.first ?? decoded.current.temperature_2m).rounded())
        let sunset = decoded.daily.sunset.first ?? "--:--"

        // Simple condition mapping by humidity/wind/temp (placeholder)
        let condition = tempF > 75 ? "Sunny" : (humidity > 70 ? "Humid" : "Clear")
        let moon = "Waning crescent" // Placeholder; Open‑Meteo has moon_phase in other endpoints

        return WeatherData(
            condition: condition,
            temperatureF: tempF,
            feelsLikeF: feelsF,
            lowF: low,
            highF: high,
            windMph: wind,
            humidityPct: humidity,
            sunset: sunsetSuffixTime(sunset),
            moonPhase: moon
        )
    }

    private func sunsetSuffixTime(_ iso: String) -> String {
        // iso example: 2025-10-30T17:22
        if let tIndex = iso.firstIndex(of: "T") {
            let time = iso[iso.index(after: tIndex)...]
            return String(time)
        }
        return iso
    }
}

// MARK: - Mock Weather

final class MockWeatherAPI: WeatherAPI {
    func fetchWeather(latitude: Double, longitude: Double) async throws -> WeatherData {
        return WeatherData(
            condition: "Clear",
            temperatureF: 51,
            feelsLikeF: 46,
            lowF: 39,
            highF: 53,
            windMph: 7,
            humidityPct: 40,
            sunset: "17:22",
            moonPhase: "Waning crescent"
        )
    }
}


