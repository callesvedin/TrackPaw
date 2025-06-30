//
//  swift
//  Satchi
//
//  Created by carl-johan.svedin on 2021-04-06.
//

import CoreLocation
import Foundation
import os.log
import SwiftState
import SwiftUI

enum RunningState: StateType {
    case notStarted, running, paused, done, viewing
}

enum RunningEvent: EventType {
    case start, pause, resume, stop
}

class TrackMapModel: NSObject, ObservableObject {
    private var locationManager: CLLocationManager
    //    public var image: UIImage?

//    public var regionIsSet: Bool = false
    private var trackingStarted: Date?

    private var track: Track
    public var preview: Bool

    public var showButtons: Bool
    public var stateMachine: Machine<RunningState, RunningEvent>!

    var trailStartLocation: CLLocationCoordinate2D? {didSet {
        trailStartUpdated()
    }}

    var trailEndLocation: CLLocationCoordinate2D? {didSet {
        trailEndUpdated()
    }}

    var trackStartLocation: CLLocationCoordinate2D? {didSet {
        trackStartUpdated()
    }}

    var trackEndLocation: CLLocationCoordinate2D? {didSet {
        trackEndUpdated()
    }}

    public var isTracking = false
    var followUser: Bool = true
    @MainActor @Published var timer: TrackTimer = .init()
    @MainActor @Published var distance: CLLocationDistance = 0
    @MainActor @Published public var gotUserLocation = false
    private var currentLocation: CLLocation?
    @MainActor @Published public var accuracy: Double = 0
    @MainActor @Published public var done: Bool = false
    @MainActor @Published public var showAccessDenied: Bool = false
    public var mapAnnotations: [PathAnnotationKind] = []

    @MainActor public var locationAuthorizationStatus: CLAuthorizationStatus {
        didSet {
            if preview {
                Logger.mapView.debug("Preview mode - skipping location authorization handling")
                return
            }
            switch locationAuthorizationStatus {
            case .notDetermined:
                Logger.mapView.info("Status not determined. Requesting authorization")
                locationManager.requestAlwaysAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                startTracking()
            case .denied, .restricted:
                showAccessDenied = true
                Logger.mapView.info("LocationAuthorizationStatus prohibits tracking")
            @unknown default:
                gotUserLocation = false
            }
        }
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: TrackMapModel.self)
    )

    @MainActor @Published public var laidPath: [CLLocation] = [] {
        didSet {
            if laidPath.count >= 2 {
                distance = getLength(from: laidPath)
            }
        }
    }

    @MainActor public var laidCoordinates: [CLLocationCoordinate2D] {
        return laidPath.map { $0.coordinate }
    }

    @MainActor @Published public var trackPath: [CLLocation] = [] {
        didSet {
            if trackPath.count >= 2 {
                distance = getLength(from: trackPath)
            }
        }
    }

    @MainActor public var trackCoordinates: [CLLocationCoordinate2D] {
        return trackPath.map { $0.coordinate }
    }

    @MainActor init(track: Track, preview: Bool = false, showButtons: Bool = true, locationManager: CLLocationManager = CLLocationManager()) {
        Logger.mapView.debug("TrackMapModel initialized Track: \(track.name)-\(track.id?.uuidString ?? "*")")
        self.track = track
        self.preview = preview || track.getState() == .trailTracked
        self.showButtons = showButtons
        laidPath = track.laidPath ?? []
        trackPath = track.trackPath ?? []

        stateMachine = Machine(state: preview ? .viewing : .notStarted)
        self.locationManager = locationManager
        locationAuthorizationStatus = locationManager.authorizationStatus

        super.init()
        if locationAuthorizationStatus == .denied || locationAuthorizationStatus == .restricted || preview {
            followUser = false
            distance = Double(track.length)
            timer.secondsElapsed = track.timeToFinish
        }

        if !preview {
            self.locationManager.allowsBackgroundLocationUpdates = true
            self.locationManager.pausesLocationUpdatesAutomatically = false
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            
            self.locationManager.delegate = self
            if locationAuthorizationStatus == .notDetermined {
                self.locationManager.requestAlwaysAuthorization()
            }
        } else {
            Logger.mapView.debug("Preview mode - skipping location manager setup")
        }

        if track.getState() == .trailTracked {
            trackStartLocation = trackPath.first?.coordinate
            self.mapAnnotations.append(PathAnnotationKind.trackingStart(location: trackStartLocation!))
            trackEndLocation = trackPath.last?.coordinate
            self.mapAnnotations.append(PathAnnotationKind.trackingEnd(location: trackEndLocation!))
        }

        if track.getState() == .trailAdded || track.getState() == .trailTracked {
            trailStartLocation = laidPath.first?.coordinate
            self.mapAnnotations.append(PathAnnotationKind.trailStart(location: trailStartLocation!))
            trailEndLocation = laidPath.last?.coordinate
            self.mapAnnotations.append(PathAnnotationKind.trailEnd(location: trailEndLocation!))
        }
        stateMachine.addRouteMapping { event, fromState, _ -> RunningState? in
            // no route for no-event
            guard let event = event else { return nil }

            switch (event, fromState) {
            case (.start, .notStarted):
                return .running
            case (.pause, .running):
                return .paused
            case (.stop, .paused):
                return .done
            case (.resume, .paused):
                return .running
            case (.stop, .viewing):
                return .done
            case (.stop, .notStarted):
                return .done

            default:
                Logger.mapView.debug("Unknown event \(String(describing: event)) from state \(String(describing: fromState))")
                return nil
            }
        }

        stateMachine.addHandler(event: .start) { context in
            Logger.mapView.debug(".start is triggered! Context:\(String(describing: context))")
            self.startRunning()
        }
        stateMachine.addHandler(event: .pause) { context in
            Logger.mapView.debug(".pause is triggered! Context:\(String(describing: context))")
            self.pauseRunning()
        }
        stateMachine.addHandler(event: .stop) { context in
            Logger.mapView.debug(".stop is triggered! Context:\(String(describing: context))")
            if context.fromState == .viewing {
                self.stopRunning()
            } else if context.fromState == .notStarted {
                self.cancelRunning()

            } else if context.fromState == .paused {
                self.stopRunning()
            }
        }
        stateMachine.addHandler(event: .resume) { context in
            Logger.mapView.debug(".resume is triggered! Context:\(String(describing: context))")
            self.resumeRunning()
        }
    }

    deinit {
        locationManager.delegate = nil
    }

    @MainActor private func resumeRunning() {
        timer.resume()
        if track.getState() == .notStarted {
            trailEndLocation = nil
        } else {
            trackEndLocation = nil
        }
    }

    private func stopRunning() {
        Task { @MainActor in
            switch track.getState() {
            case .notStarted:
                track.laidPath = laidPath
                track.trackPath = trackPath
                track.timeToCreate = timer.secondsElapsed
                track.length = Int32(distance)
                track.created = Date()
                track.state = track.getState().rawValue
                //            track.dummies = dummies
                await PersistenceController.shared.updateTrack(track: track)
            case .trailAdded:
                track.trackPath = trackPath
                track.timeToFinish = timer.secondsElapsed
                track.started = trackingStarted
                track.state = track.getState().rawValue
                await PersistenceController.shared.updateTrack(track: track)
            default:
                let state = track.getState()
                Logger.mapView.debug("Unknown state when stopRunning is called \(String(describing: state))")
            }
            stopTracking()
            done = true
        }
    }

    @MainActor private func pauseRunning() {
        timer.stop()
        switch track.getState() {
        case .notStarted:
            trailEndLocation = laidPath.last?.coordinate
        case .trailAdded:
            trackEndLocation = trackPath.last?.coordinate
        default:
            let state = track.getState()
            Logger.mapView.debug("Can not pause Running on track state \(String(describing: state)). Maybe view() instead")
            return
        }
    }

    @MainActor private func startRunning() {
        switch track.getState() {
        case .notStarted:
            trailStartLocation = currentLocation?.coordinate
            timer.start()
        case .trailAdded:
            trailStartLocation = laidPath.first?.coordinate
            trailEndLocation = laidPath.last?.coordinate
            trackingStarted = Date()
            trackStartLocation = currentLocation?.coordinate
            timer.start()
        default:
            let state = track.getState()
            Logger.mapView.debug("Can not start Running on track state \(String(describing: state)). Maybe view() instead")
            return
        }
    }

    @MainActor private func cancelRunning() {
        stopTracking()
        done = true
    }

    public func start() {
        if preview {
            Logger.mapView.debug("Preview mode - ignoring start action")
            return
        }
        stateMachine <-! .start
    }

    public func pause() {
        if preview{
            Logger.mapView.debug("Preview mode - ignoring pause action")
            return
        }
        stateMachine <-! .pause
    }

    public func resume() {
        if preview {
            Logger.mapView.debug("Preview mode - ignoring resume action")
            return
        }
        stateMachine <-! .resume
    }

    public func stop() {
        stateMachine <-! .stop
    }

//    public func addDummy() {
//        Logger.mapView.debug("Add dummy now!")
//        if let location = locationManager.location {
//            dummies.append(location.coordinate)
//        }
//    }

    private func getLength(from locations: [CLLocation]) -> Double {
        var length: Double = 0
        for (changed, location) in locations.enumerated() {
            if changed == 0 { continue }
            length += location.distance(from: locations[changed - 1])
        }
        return length
    }

    public func startTracking() {
        Logger.mapView.debug("Start tracking.")
        if preview {
            Logger.mapView.debug("Preview mode - skipping location tracking")
            return
        }
        if !isTracking {
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
            locationManager.startMonitoringSignificantLocationChanges()

            isTracking = true
        }
    }

    private func stopTracking() {
        Logger.mapView.debug("Stop tracking.")
        locationManager.stopUpdatingHeading()
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        locationManager.stopMonitoringSignificantLocationChanges()
        isTracking = false
        locationManager.delegate = nil
    }

    fileprivate func trailStartUpdated() {
        if trailStartLocation == nil {
            if let i = self.mapAnnotations.firstIndex(where: {
                switch $0 {
                case .trailStart: return true
                default: return false
                }
            }) {
                self.mapAnnotations.remove(at: i)
            }
        } else {
            self.mapAnnotations.append( PathAnnotationKind.trailStart(location: trailStartLocation!))
        }
    }

    fileprivate func trailEndUpdated() {
        if trailEndLocation == nil {
            if let i = self.mapAnnotations.firstIndex(where: {
                switch $0 {
                case .trailEnd: return true
                default: return false
                }
            }) {
                self.mapAnnotations.remove(at: i)
            }

        }else {
            self.mapAnnotations.append( PathAnnotationKind.trailEnd(location: trailEndLocation!))
        }
    }

    fileprivate func trackStartUpdated() {
        if trackStartLocation == nil {
            if let i = self.mapAnnotations.firstIndex(where: {
                switch $0 {
                case .trackingStart: return true
                default: return false
                }
            }) {
                self.mapAnnotations.remove(at: i)
            }

        }else {
            self.mapAnnotations.append(PathAnnotationKind.trackingStart(location: trackStartLocation!))
        }
    }

    fileprivate func trackEndUpdated() {
        if trackEndLocation == nil {
            if let i = self.mapAnnotations.firstIndex(where: {
                switch $0 {
                case .trackingEnd: return true
                default: return false
                }
            }) {
                self.mapAnnotations.remove(at: i)
            }

        }else {
            self.mapAnnotations.append(PathAnnotationKind.trackingStart(location: trackEndLocation!))
        }
    }
}

extension TrackMapModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            // If we want to continue updating while paused we have to add .paused state here but we then have to save the location where we paused...
            if stateMachine.state == .running && track.getState() == .notStarted {
                laidPath.append(contentsOf: locations)
                // If we want to continue updating while paused we have to add .paused state here but we then have to save the location where we paused...
            } else if stateMachine.state == .running && track.getState() == .trailAdded {
                trackPath.append(contentsOf: locations)
            }
            accuracy = locations.first?.horizontalAccuracy ?? 0
            currentLocation = manager.location
            gotUserLocation = true
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            Logger.mapView.debug("locationManagerDidChangeAuthorization:manager. Status:\(String(describing: manager.authorizationStatus))")
            locationAuthorizationStatus = manager.authorizationStatus
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Logger.mapView.debug("Location manager failed. \(error.localizedDescription)")
    }

    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        Logger.mapView.debug("Location manager paused location updates.")
    }
}
