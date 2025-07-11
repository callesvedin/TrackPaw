//
//  LocationManager.swift
//  Satchi
//
//  Created by claude on 2025-07-10.
//

import CoreLocation
import Foundation
import SwiftUI
import os.log

public protocol LocationManagerDelegate: AnyObject {
    func locationManager(_ manager: LocationManager, didUpdateLocations locations: [CLLocation])
    func locationManager(_ manager: LocationManager, didChangeAuthorization status: CLAuthorizationStatus)
    func locationManager(_ manager: LocationManager, didFailWithError error: Error)
}

class WeakLocationManagerDelegate {
    weak var delegate: LocationManagerDelegate?
    
    init(_ delegate: LocationManagerDelegate) {
        self.delegate = delegate
    }
}

public class LocationManager: NSObject, ObservableObject {
    public static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    private var delegates: [WeakLocationManagerDelegate] = []
    private var isTracking = false
    
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var currentLocation: CLLocation?
    @Published var accuracy: Double = 0
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: LocationManager.self)
    )
    
    private override init() {
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
    }
    
    public func subscribe(_ delegate: LocationManagerDelegate) {
        LocationManager.logger
            .debug(
                "😃 LocationManager: Adding subscriber (\(self.delegates.count))"
            )

        // Remove any existing reference to this delegate
        unsubscribe(delegate)
        
        // Add new reference
        delegates.append(WeakLocationManagerDelegate(delegate))
        
        // Clean up any nil references
        cleanupDelegates()
        
        // Start tracking if we have active delegates and not already tracking
        if !delegates.isEmpty && !isTracking {
            startLocationTracking()
        }
        LocationManager.logger
            .debug(
                "😃 LocationManager: Adding subscriber done (\(self.delegates.count))"
            )

    }
    
    public func unsubscribe(_ delegate: LocationManagerDelegate) {
        LocationManager.logger.debug("😢 LocationManager: Removing subscriber (\(self.delegates.count))")

        delegates.removeAll { weakDelegate in
            guard let existingDelegate = weakDelegate.delegate else { return true }
            return existingDelegate === delegate
        }
        
        cleanupDelegates()
        
        // Stop tracking if no active delegates
        if delegates.isEmpty && isTracking {
            stopLocationTracking()
        }
        LocationManager.logger.debug("😢 LocationManager: Removing subscriber done (\(self.delegates.count))")
    }
    
    private func cleanupDelegates() {
        delegates.removeAll { $0.delegate == nil }
    }
    
    public func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    private func startLocationTracking() {
        guard !isTracking else { return }
        
        LocationManager.logger.debug("✅ LocationManager: Starting location tracking")
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        locationManager.startMonitoringSignificantLocationChanges()
        isTracking = true
    }
    
    private func stopLocationTracking() {
        guard isTracking else { return }
        
        LocationManager.logger.debug("🚫 LocationManager: Stopping location tracking")
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        locationManager.stopMonitoringSignificantLocationChanges()
        isTracking = false
    }
    
    private func notifyDelegates(_ action: (LocationManagerDelegate) -> Void) {
        cleanupDelegates()
        delegates.forEach { weakDelegate in
            guard let delegate = weakDelegate.delegate else { return }
            action(delegate)
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async {
            self.currentLocation = manager.location
            self.accuracy = locations.first?.horizontalAccuracy ?? 0
        }
        
        notifyDelegates { delegate in
            delegate.locationManager(self, didUpdateLocations: locations)
        }
    }
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            LocationManager.logger.debug(
                "LocationManager: Authorization changed to \(String(describing: manager.authorizationStatus))"
            )
            self.authorizationStatus = manager.authorizationStatus
        }
        
        notifyDelegates { delegate in
            delegate.locationManager(self, didChangeAuthorization: manager.authorizationStatus)
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        LocationManager.logger.debug("LocationManager: Failed with error \(error.localizedDescription)")
        
        notifyDelegates { delegate in
            delegate.locationManager(self, didFailWithError: error)
        }
    }
    
    public func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        LocationManager.logger.debug("LocationManager: Paused location updates")
    }
}
