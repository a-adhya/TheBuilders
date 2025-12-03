//
//  LocationService.swift
//  TheBuilders
//
//  Service for getting device GPS location
//

import Foundation
import CoreLocation
import Combine

enum LocationError: LocalizedError {
    case authorizationDenied
    case authorizationRestricted
    case locationUnavailable
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Location access denied. Please enable location services in Settings."
        case .authorizationRestricted:
            return "Location access is restricted on this device."
        case .locationUnavailable:
            return "Location services are unavailable."
        case .unknownError:
            return "An unknown error occurred while getting location."
        }
    }
}

@MainActor
class LocationService: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var authorizationContinuation: CheckedContinuation<Void, Error>?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func getCurrentLocation() async throws -> (latitude: Double, longitude: Double) {
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            // Request authorization and wait for the response
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.authorizationContinuation = continuation
                locationManager.requestWhenInUseAuthorization()
            }
            
        case .denied, .restricted:
            throw LocationError.authorizationDenied
            
        case .authorizedWhenInUse, .authorizedAlways:
            break
            
        @unknown default:
            throw LocationError.unknownError
        }
        
        let finalStatus = locationManager.authorizationStatus
        guard finalStatus == .authorizedWhenInUse || finalStatus == .authorizedAlways else {
            throw LocationError.authorizationDenied
        }
        
        let location = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLLocation, Error>) in
            self.locationContinuation = continuation
            locationManager.requestLocation()
        }
        
        return (location.coordinate.latitude, location.coordinate.longitude)
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            if let continuation = authorizationContinuation {
                switch status {
                case .authorizedWhenInUse, .authorizedAlways:
                    authorizationContinuation = nil
                    continuation.resume()
                case .denied, .restricted:
                    authorizationContinuation = nil
                    continuation.resume(throwing: LocationError.authorizationDenied)
                case .notDetermined:
                    // Still waiting for user response, don't resume yet
                    break
                @unknown default:
                    authorizationContinuation = nil
                    continuation.resume(throwing: LocationError.unknownError)
                }
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        Task { @MainActor in
            if let continuation = locationContinuation {
                locationContinuation = nil
                continuation.resume(returning: location)
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if let continuation = locationContinuation {
                locationContinuation = nil
                continuation.resume(throwing: error)
            }
        }
    }
}

