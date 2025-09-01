//
//  swift
//  TrackPaw
//
//  Created by carl-johan.svedin on 2021-04-06.
//

import CoreLocation
import Foundation
import SwiftState
import SwiftUI
import os.log

enum RunningState: StateType {
    case notStarted, running, paused, done, viewing
}

enum RunningEvent: EventType {
    case start, pause, resume, stop
}

@Observable
class TrackMapModel: NSObject, LocationManagerDelegate {
    private var trackingStarted: Date?

    private var track: Track
    public var preview: Bool

    public var showButtons: Bool
    private var stateMachine: Machine<RunningState, RunningEvent>!

    // Observable wrapper for stateMachine.state
    public var currentState: RunningState = .notStarted

    var trailStartLocation: CLLocationCoordinate2D? {
        didSet {
            trailStartUpdated()
        }
    }

    var trailEndLocation: CLLocationCoordinate2D? {
        didSet {
            trailEndUpdated()
        }
    }

    var trackStartLocation: CLLocationCoordinate2D? {
        didSet {
            trackStartUpdated()
        }
    }

    var trackEndLocation: CLLocationCoordinate2D? {
        didSet {
            trackEndUpdated()
        }
    }

    @MainActor public var isTracking = false
    // private var followUser: Bool = true
    var timer: TrackTimer = .init()
    var distance: CLLocationDistance = 0
    public var gotUserLocation = false
    private var currentLocation: CLLocation?
    public var accuracy: Double = 0
    public var done: Bool = false
    public var showAccessDenied: Bool = false
    public var mapAnnotations: [PathAnnotationKind] = []

    public var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: TrackMapModel.self)
    )

     public var laidPath: [CLLocation] = [] {
        didSet {
            if laidPath.count >= 2 {
                distance = getLength(from: laidPath)
            }
        }
    }

     public var laidCoordinates: [CLLocationCoordinate2D] {
        return laidPath.map { $0.coordinate }
    }

     public var trackPath: [CLLocation] = [] {
        didSet {
            if trackPath.count >= 2 {
                distance = getLength(from: trackPath)
            }
        }
    }

    public var trackCoordinates: [CLLocationCoordinate2D] {
        return trackPath.map { $0.coordinate }
    }

   @MainActor init(
        track: Track,
        preview: Bool = false,
        showButtons: Bool = true
    ) {
        Logger.mapView.debug(
            "TrackMapModel initialized Track: \(track.name)-\(track.id?.uuidString ?? "*")"
        )

        self.track = track
        self.preview = preview || track.getState() == .trailTracked
        self.showButtons = showButtons
        laidPath = track.laidPath ?? []
        trackPath = track.trackPath ?? []
        super.init()
        let initialState: RunningState = self.preview ? .viewing : .notStarted
        stateMachine = Machine(state: initialState)
        _currentState = initialState
        locationAuthorizationStatus = LocationManager.shared.authorizationStatus

        if locationAuthorizationStatus == .denied
            || locationAuthorizationStatus == .restricted || self.preview
        {
            distance = Double(track.length)
            timer.secondsElapsed = track.timeToFinish
        }

        if !self.preview {
            LocationManager.shared.subscribe(self)
            if locationAuthorizationStatus == .notDetermined || locationAuthorizationStatus == .denied || locationAuthorizationStatus == .restricted {
                showAccessDenied = true
            }
            if locationAuthorizationStatus == .notDetermined || locationAuthorizationStatus == .restricted {
                LocationManager.shared.requestAlwaysAuthorization()
            }
        } else {
            Logger.mapView.debug(
                "Preview mode - skipping location manager setup"
            )
        }

         if track.getState() == .trailTracked {
            trackStartLocation = trackPath.first?.coordinate
//            self.mapAnnotations.append(
//                PathAnnotationKind.trackingStart(location: trackStartLocation!)
//            )
            trackEndLocation = trackPath.last?.coordinate
//            self.mapAnnotations.append(
//                PathAnnotationKind.trackingEnd(location: trackEndLocation!)
//            )
         }

        if track.getState() == .trailAdded || track.getState() == .trailTracked
        {
            trailStartLocation = laidPath.first?.coordinate
//            self.mapAnnotations.append(
//                PathAnnotationKind.trailStart(location: trailStartLocation!)
//            )
            trailEndLocation = laidPath.last?.coordinate
//            self.mapAnnotations.append(
//                PathAnnotationKind.trailEnd(location: trailEndLocation!)
//            )
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
                Logger.mapView.debug(
                    "Unknown event \(String(describing: event)) from state \(String(describing: fromState))"
                )
                return nil
            }
        }

        stateMachine.addHandler(event: .start) { context in
            Logger.mapView.debug(
                ".start is triggered! Context:\(String(describing: context))"
            )
            self.currentState = self.stateMachine.state
            self.startRunning()
        }
        stateMachine.addHandler(event: .pause) { context in
            Logger.mapView.debug(
                ".pause is triggered! Context:\(String(describing: context))"
            )
            self.currentState = self.stateMachine.state
            self.pauseRunning()
        }
        stateMachine.addHandler(event: .stop) { context in
            Logger.mapView.debug(
                ".stop is triggered! Context:\(String(describing: context))"
            )
            self.currentState = self.stateMachine.state
            self.done = true
            if context.fromState == .viewing {
                self.stopRunning()
            } else if context.fromState == .notStarted {
                self.cancelRunning()

            } else if context.fromState == .paused {
                self.stopRunning()
            }
        }
        stateMachine.addHandler(event: .resume) { context in
            Logger.mapView.debug(
                ".resume is triggered! Context:\(String(describing: context))"
            )
            self.currentState = self.stateMachine.state
            self.resumeRunning()
        }
    }

    deinit {
        if !preview {
            LocationManager.shared.unsubscribe(self)
        }
        Logger.mapView.debug("TrackMapModel deinitialized")
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
                Logger.mapView.debug(
                    "Unknown state when stopRunning is called \(String(describing: state))"
                )
            }
            LocationManager.shared.unsubscribe(self)
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
            Logger.mapView.debug(
                "Can not pause Running on track state \(String(describing: state)). Maybe view() instead"
            )
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
            Logger.mapView.debug(
                "Can not start Running on track state \(String(describing: state)). Maybe view() instead"
            )
            return
        }
    }

    @MainActor private func cancelRunning() {
        LocationManager.shared.unsubscribe(self)
    }

    @MainActor public func start() {
        if preview {
            Logger.mapView.debug("Preview mode - ignoring start action")
            return
        }
        stateMachine <-! .start
    }

    @MainActor public func pause() {
        if preview {
            Logger.mapView.debug("Preview mode - ignoring pause action")
            return
        }
        stateMachine <-! .pause
    }

    @MainActor public func resume() {
        if preview {
            Logger.mapView.debug("Preview mode - ignoring resume action")
            return
        }
        stateMachine <-! .resume
    }

    @MainActor public func stop() {
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

    public func startTracking() async {
        Logger.mapView.debug("Start tracking.")
        if preview {
            Logger.mapView.debug("Preview mode - skipping location tracking")
            return
        }
        await MainActor.run {
            isTracking = true
        }
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
            self.mapAnnotations.append(
                PathAnnotationKind.trailStart(location: trailStartLocation!)
            )
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

        } else {
            self.mapAnnotations.append(
                PathAnnotationKind.trailEnd(location: trailEndLocation!)
            )
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

        } else {
            self.mapAnnotations.append(
                PathAnnotationKind.trackingStart(location: trackStartLocation!)
            )
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

        } else {
            self.mapAnnotations.append(
                PathAnnotationKind.trackingEnd(location: trackEndLocation!)
            )
        }
    }
}

extension TrackMapModel {
    func locationManager(
        _ manager: LocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        // If we want to continue updating while paused we have to add .paused state here but we then have to save the location where we paused...
        if currentState == .running && track.getState() == .notStarted
        {
            laidPath.append(contentsOf: locations)
            // If we want to continue updating while paused we have to add .paused state here but we then have to save the location where we paused...
        } else if currentState == .running
            && track.getState() == .trailAdded
        {
            trackPath.append(contentsOf: locations)
        }
        accuracy = locations.first?.horizontalAccuracy ?? 0
        currentLocation = LocationManager.shared.currentLocation
        gotUserLocation = true
    }

    func locationManager(
        _ manager: LocationManager,
        didChangeAuthorization status: CLAuthorizationStatus
    )  {
        Logger.mapView.debug(
            "locationManagerDidChangeAuthorization. Status:\(String(describing: status))"
        )
        locationAuthorizationStatus = status
        
        if preview {
            Logger.mapView.debug(
                "Preview mode - skipping location authorization handling"
            )
            return
        }
        
        switch status {
        case .notDetermined:
            Logger.mapView.info(
                "Status not determined. Requesting authorization"
            )
            showAccessDenied = true
            LocationManager.shared.requestAlwaysAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            showAccessDenied = false
            Task {
                await startTracking()
            }
        case .denied, .restricted:
            showAccessDenied = true
            Logger.mapView.info(
                "LocationAuthorizationStatus prohibits tracking"
            )
        @unknown default:
            showAccessDenied = true
            gotUserLocation = false
        }
    }

    func locationManager(
        _ manager: LocationManager,
        didFailWithError error: Error
    ) {
        Logger.mapView.debug(
            "Location manager failed. \(error.localizedDescription)"
        )
    }
}
