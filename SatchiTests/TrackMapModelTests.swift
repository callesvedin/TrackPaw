//
//  TrackMapModelTests.swift
//  SatchiTests
//
//  Created by Claude on 2025-07-22.
//

import XCTest
import CoreLocation
import CoreData
import SwiftState
@testable import Satchi

class TrackMapModelTests: XCTestCase {
    
    var trackMapModel: TrackMapModel!
    var mockTrack: Track!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
//        let context = PersistenceController.shared.container.viewContext
        let context = PersistenceController.shared
            .persistentContainer.viewContext
        mockTrack = Track(context: context, name: "Test Track", id: UUID())
        mockTrack.state = TrackState.notStarted.rawValue
        mockTrack.length = 0
        mockTrack.timeToCreate = 0
        mockTrack.timeToFinish = 0
        mockTrack.comments = ""
        mockTrack.difficulty = 1
        
        try context.save()
    }
    
    override func tearDownWithError() throws {
        trackMapModel = nil
        if let track = mockTrack {
            let context = track.managedObjectContext
            context?.delete(track)
            try context?.save()
        }
        mockTrack = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    @MainActor
    func testInitialization_WithDefaultParameters() throws {
        trackMapModel = TrackMapModel(track: mockTrack)
        
        XCTAssertEqual(trackMapModel.currentState, .notStarted)
        XCTAssertFalse(trackMapModel.preview)
        XCTAssertTrue(trackMapModel.showButtons)
        XCTAssertFalse(trackMapModel.isTracking)
        XCTAssertFalse(trackMapModel.gotUserLocation)
        XCTAssertFalse(trackMapModel.done)
        XCTAssertFalse(trackMapModel.showAccessDenied)
        XCTAssertEqual(trackMapModel.distance, 0)
        XCTAssertEqual(trackMapModel.accuracy, 0)
        XCTAssertTrue(trackMapModel.laidPath.isEmpty)
        XCTAssertTrue(trackMapModel.trackPath.isEmpty)
        XCTAssertTrue(trackMapModel.mapAnnotations.isEmpty)
    }
    
    @MainActor
    func testInitialization_WithPreviewMode() throws {
        trackMapModel = TrackMapModel(track: mockTrack, preview: true)
        
        XCTAssertEqual(trackMapModel.currentState, .viewing)
        XCTAssertTrue(trackMapModel.preview)
        XCTAssertTrue(trackMapModel.showButtons)
    }
    
    @MainActor
    func testInitialization_WithShowButtonsFalse() throws {
        trackMapModel = TrackMapModel(track: mockTrack, showButtons: false)
        
        XCTAssertFalse(trackMapModel.showButtons)
        XCTAssertEqual(trackMapModel.currentState, .notStarted)
        XCTAssertFalse(trackMapModel.preview)
    }
    
    @MainActor
    func testInitialization_WithTrailTrackedTrack() throws {
        mockTrack.timeToFinish = 100.0
        mockTrack.laidPath = [
            CLLocation(latitude: 59.3293, longitude: 18.0686),
            CLLocation(latitude: 59.3294, longitude: 18.0687)
        ]
        mockTrack.trackPath = [
            CLLocation(latitude: 59.3295, longitude: 18.0688),
            CLLocation(latitude: 59.3296, longitude: 18.0689)
        ]
        
        trackMapModel = TrackMapModel(track: mockTrack)
        
        XCTAssertTrue(trackMapModel.preview)
        XCTAssertEqual(trackMapModel.currentState, .viewing)
        XCTAssertEqual(trackMapModel.laidPath.count, 2)
        XCTAssertEqual(trackMapModel.trackPath.count, 2)
        XCTAssertEqual(trackMapModel.mapAnnotations.count, 4)
    }
    
    @MainActor
    func testInitialization_WithTrailAddedTrack() throws {
        mockTrack.timeToCreate = 50.0
        mockTrack.laidPath = [
            CLLocation(latitude: 59.3293, longitude: 18.0686),
            CLLocation(latitude: 59.3294, longitude: 18.0687)
        ]
        
        trackMapModel = TrackMapModel(track: mockTrack)
        
        XCTAssertEqual(trackMapModel.currentState, .notStarted)
        XCTAssertEqual(trackMapModel.laidPath.count, 2)
        XCTAssertEqual(trackMapModel.mapAnnotations.count, 2)
        XCTAssertTrue(trackMapModel.mapAnnotations.contains { annotation in
            switch annotation {
            case .trailStart: return true
            default: return false
            }
        })
        XCTAssertTrue(trackMapModel.mapAnnotations.contains { annotation in
            switch annotation {
            case .trailEnd: return true
            default: return false
            }
        })
    }
    
    // MARK: - State Machine Tests
    
    @MainActor
    func testStateTransition_StartFromNotStarted() throws {
        trackMapModel = TrackMapModel(track: mockTrack)
        
        trackMapModel.start()
        
        XCTAssertEqual(trackMapModel.currentState, .running)
    }
    
    @MainActor
    func testStateTransition_PauseFromRunning() throws {
        trackMapModel = TrackMapModel(track: mockTrack)
        trackMapModel.start()
        
        trackMapModel.pause()
        
        XCTAssertEqual(trackMapModel.currentState, .paused)
    }
    
    @MainActor
    func testStateTransition_ResumeFromPaused() throws {
        trackMapModel = TrackMapModel(track: mockTrack)
        trackMapModel.start()
        trackMapModel.pause()
        
        trackMapModel.resume()
        
        XCTAssertEqual(trackMapModel.currentState, .running)
    }
    
    @MainActor
    func testStateTransition_StopFromPaused() throws {
        trackMapModel = TrackMapModel(track: mockTrack)
        trackMapModel.start()
        trackMapModel.pause()
        
        trackMapModel.stop()
        
        XCTAssertEqual(trackMapModel.currentState, .done)
        XCTAssertTrue(trackMapModel.done)
    }
    
    @MainActor
    func testStateTransition_StopFromNotStarted() throws {
        trackMapModel = TrackMapModel(track: mockTrack)
        
        trackMapModel.stop()
        
        XCTAssertEqual(trackMapModel.currentState, .done)
        XCTAssertTrue(trackMapModel.done)
    }
    
    @MainActor
    func testStateTransition_StopFromViewing() throws {
        trackMapModel = TrackMapModel(track: mockTrack, preview: true)
        
        trackMapModel.stop()
        
        XCTAssertEqual(trackMapModel.currentState, .done)
        XCTAssertTrue(trackMapModel.done)
    }
    
    // MARK: - Preview Mode Tests
    
    @MainActor
    func testPreviewMode_IgnoresStateTransitions() throws {
        trackMapModel = TrackMapModel(track: mockTrack, preview: true)
        
        trackMapModel.start()
        XCTAssertEqual(trackMapModel.currentState, .viewing)
        
        trackMapModel.pause()
        XCTAssertEqual(trackMapModel.currentState, .viewing)
        
        trackMapModel.resume()
        XCTAssertEqual(trackMapModel.currentState, .viewing)
    }
    
    @MainActor
    func testPreviewMode_AllowsStop() throws {
        trackMapModel = TrackMapModel(track: mockTrack, preview: true)
        
        trackMapModel.stop()
        
        XCTAssertEqual(trackMapModel.currentState, .done)
        XCTAssertTrue(trackMapModel.done)
    }
    
    // MARK: - Distance Calculation Tests
    
    @MainActor
    func testDistanceCalculation_WithLaidPath() throws {
        trackMapModel = TrackMapModel(track: mockTrack)
        
        let location1 = CLLocation(latitude: 59.3293, longitude: 18.0686)
        let location2 = CLLocation(latitude: 59.3294, longitude: 18.0687)
        
        trackMapModel.laidPath = [location1, location2]
        
        let expectedDistance = location2.distance(from: location1)
        XCTAssertEqual(trackMapModel.distance, expectedDistance, accuracy: 0.1)
    }
    
    @MainActor
    func testDistanceCalculation_WithTrackPath() throws {
        trackMapModel = TrackMapModel(track: mockTrack)
        
        let location1 = CLLocation(latitude: 59.3293, longitude: 18.0686)
        let location2 = CLLocation(latitude: 59.3294, longitude: 18.0687)
        
        trackMapModel.trackPath = [location1, location2]
        
        let expectedDistance = location2.distance(from: location1)
        XCTAssertEqual(trackMapModel.distance, expectedDistance, accuracy: 0.1)
    }
    
    @MainActor
    func testDistanceCalculation_WithMultipleLocations() throws {
        trackMapModel = TrackMapModel(track: mockTrack)
        
        let locations = [
            CLLocation(latitude: 59.3293, longitude: 18.0686),
            CLLocation(latitude: 59.3294, longitude: 18.0687),
            CLLocation(latitude: 59.3295, longitude: 18.0688)
        ]
        
        trackMapModel.laidPath = locations
        
        let expectedDistance = locations[1].distance(from: locations[0]) + locations[2].distance(from: locations[1])
        XCTAssertEqual(trackMapModel.distance, expectedDistance, accuracy: 0.1)
    }
    
    // MARK: - Coordinate Tests
    
    @MainActor
    func testLaidCoordinates_ReturnsCorrectCoordinates() throws {
        trackMapModel = TrackMapModel(track: mockTrack)
        
        let location1 = CLLocation(latitude: 59.3293, longitude: 18.0686)
        let location2 = CLLocation(latitude: 59.3294, longitude: 18.0687)
        trackMapModel.laidPath = [location1, location2]
        
        let coordinates = trackMapModel.laidCoordinates
        
        XCTAssertEqual(coordinates.count, 2)
        XCTAssertEqual(coordinates[0].latitude, location1.coordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(coordinates[0].longitude, location1.coordinate.longitude, accuracy: 0.0001)
        XCTAssertEqual(coordinates[1].latitude, location2.coordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(coordinates[1].longitude, location2.coordinate.longitude, accuracy: 0.0001)
    }
    
    @MainActor
    func testTrackCoordinates_ReturnsCorrectCoordinates() throws {
        trackMapModel = TrackMapModel(track: mockTrack)
        
        let location1 = CLLocation(latitude: 59.3293, longitude: 18.0686)
        let location2 = CLLocation(latitude: 59.3294, longitude: 18.0687)
        trackMapModel.trackPath = [location1, location2]
        
        let coordinates = trackMapModel.trackCoordinates
        
        XCTAssertEqual(coordinates.count, 2)
        XCTAssertEqual(coordinates[0].latitude, location1.coordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(coordinates[0].longitude, location1.coordinate.longitude, accuracy: 0.0001)
        XCTAssertEqual(coordinates[1].latitude, location2.coordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(coordinates[1].longitude, location2.coordinate.longitude, accuracy: 0.0001)
    }
    
    // MARK: - Annotation Management Tests
    
    @MainActor
    func testTrailStartLocation_UpdatesAnnotations() throws {
        trackMapModel = TrackMapModel(track: mockTrack)
        let coordinate = CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686)
        
        trackMapModel.trailStartLocation = coordinate
        
        XCTAssertEqual(trackMapModel.mapAnnotations.count, 1)
        XCTAssertTrue(trackMapModel.mapAnnotations.contains { annotation in
            switch annotation {
            case .trailStart(let location):
                return location.latitude == coordinate.latitude && location.longitude == coordinate.longitude
            default:
                return false
            }
        })
    }
    
    @MainActor
    func testTrailStartLocation_RemovesAnnotationWhenNil() throws {
        trackMapModel = TrackMapModel(track: mockTrack)
        let coordinate = CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686)
        trackMapModel.trailStartLocation = coordinate
        
        trackMapModel.trailStartLocation = nil
        
        XCTAssertEqual(trackMapModel.mapAnnotations.count, 0)
    }
    
    @MainActor
    func testTrailEndLocation_UpdatesAnnotations() throws {
        trackMapModel = TrackMapModel(track: mockTrack)
        let coordinate = CLLocationCoordinate2D(latitude: 59.3294, longitude: 18.0687)
        
        trackMapModel.trailEndLocation = coordinate
        
        XCTAssertEqual(trackMapModel.mapAnnotations.count, 1)
        XCTAssertTrue(trackMapModel.mapAnnotations.contains { annotation in
            switch annotation {
            case .trailEnd(let location):
                return location.latitude == coordinate.latitude && location.longitude == coordinate.longitude
            default:
                return false
            }
        })
    }
    
    @MainActor
    func testTrackStartLocation_UpdatesAnnotations() throws {
        trackMapModel = TrackMapModel(track: mockTrack)
        let coordinate = CLLocationCoordinate2D(latitude: 59.3295, longitude: 18.0688)
        
        trackMapModel.trackStartLocation = coordinate
        
        XCTAssertEqual(trackMapModel.mapAnnotations.count, 1)
        XCTAssertTrue(trackMapModel.mapAnnotations.contains { annotation in
            switch annotation {
            case .trackingStart(let location):
                return location.latitude == coordinate.latitude && location.longitude == coordinate.longitude
            default:
                return false
            }
        })
    }
    
    @MainActor
    func testTrackEndLocation_UpdatesAnnotations() throws {
        trackMapModel = TrackMapModel(track: mockTrack)
        let coordinate = CLLocationCoordinate2D(latitude: 59.3296, longitude: 18.0689)
        
        trackMapModel.trackEndLocation = coordinate
        
        XCTAssertEqual(trackMapModel.mapAnnotations.count, 1)
        XCTAssertTrue(trackMapModel.mapAnnotations.contains { annotation in
            switch annotation {
            case .trackingStart(let location):
                return location.latitude == coordinate.latitude && location.longitude == coordinate.longitude
            default:
                return false
            }
        })
    }
    
    // MARK: - Location Manager Delegate Tests
    
    @MainActor
    func testLocationUpdate_InRunningStateNotStartedTrack_UpdatesLaidPath() throws {
        trackMapModel = TrackMapModel(track: mockTrack)
        trackMapModel.start()
        
        let locations = [
            CLLocation(latitude: 59.3293, longitude: 18.0686),
            CLLocation(latitude: 59.3294, longitude: 18.0687)
        ]
        
        trackMapModel.locationManager(LocationManager.shared, didUpdateLocations: locations)
        
        XCTAssertEqual(trackMapModel.laidPath.count, 2)
        XCTAssertEqual(trackMapModel.trackPath.count, 0)
        XCTAssertTrue(trackMapModel.gotUserLocation)
    }
    
    @MainActor
    func testLocationUpdate_InRunningStateTrailAddedTrack_UpdatesTrackPath() throws {
        mockTrack.timeToCreate = 50.0
        trackMapModel = TrackMapModel(track: mockTrack)
        trackMapModel.start()
        
        let locations = [
            CLLocation(latitude: 59.3293, longitude: 18.0686),
            CLLocation(latitude: 59.3294, longitude: 18.0687)
        ]
        
        trackMapModel.locationManager(LocationManager.shared, didUpdateLocations: locations)
        
        XCTAssertEqual(trackMapModel.trackPath.count, 2)
        XCTAssertEqual(trackMapModel.laidPath.count, 0)
        XCTAssertTrue(trackMapModel.gotUserLocation)
    }
    
    @MainActor
    func testLocationUpdate_InPausedState_DoesNotUpdatePath() throws {
        trackMapModel = TrackMapModel(track: mockTrack)
        trackMapModel.start()
        trackMapModel.pause()
        
        let locations = [CLLocation(latitude: 59.3293, longitude: 18.0686)]
        
        trackMapModel.locationManager(LocationManager.shared, didUpdateLocations: locations)
        
        XCTAssertEqual(trackMapModel.laidPath.count, 0)
        XCTAssertEqual(trackMapModel.trackPath.count, 0)
    }
    
    @MainActor
    func testLocationAuthorizationChange_Authorized_StartsTracking() throws {
        trackMapModel = TrackMapModel(track: mockTrack)
        
        trackMapModel.locationManager(LocationManager.shared, didChangeAuthorization: .authorizedWhenInUse)
        
        XCTAssertEqual(trackMapModel.locationAuthorizationStatus, .authorizedWhenInUse)
        XCTAssertTrue(trackMapModel.isTracking)
        XCTAssertFalse(trackMapModel.showAccessDenied)
    }
    
    @MainActor
    func testLocationAuthorizationChange_Denied_ShowsAccessDenied() throws {
        trackMapModel = TrackMapModel(track: mockTrack)
        
        trackMapModel.locationManager(LocationManager.shared, didChangeAuthorization: .denied)
        
        XCTAssertEqual(trackMapModel.locationAuthorizationStatus, .denied)
        XCTAssertTrue(trackMapModel.showAccessDenied)
    }
    
    @MainActor
    func testLocationAuthorizationChange_InPreviewMode_IgnoresChanges() throws {
        trackMapModel = TrackMapModel(track: mockTrack, preview: true)
        
        trackMapModel.locationManager(LocationManager.shared, didChangeAuthorization: .authorizedAlways)
        
        XCTAssertFalse(trackMapModel.isTracking)
        XCTAssertFalse(trackMapModel.showAccessDenied)
    }
    
    // MARK: - Timer Integration Tests
    
    @MainActor
    func testStartTracking_StartsTimer() throws {
        trackMapModel = TrackMapModel(track: mockTrack)
        
        trackMapModel.start()
        
        XCTAssertEqual(trackMapModel.timer.mode, .running)
    }
    
    @MainActor
    func testPauseTracking_StopsTimer() throws {
        trackMapModel = TrackMapModel(track: mockTrack)
        trackMapModel.start()
        
        trackMapModel.pause()
        
        XCTAssertEqual(trackMapModel.timer.mode, .stopped)
    }
    
    @MainActor
    func testResumeTracking_ResumesTimer() throws {
        trackMapModel = TrackMapModel(track: mockTrack)
        trackMapModel.start()
        trackMapModel.pause()
        
        trackMapModel.resume()
        
        XCTAssertEqual(trackMapModel.timer.mode, .running)
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testPerformance_LargeLocationArray() throws {
        trackMapModel = TrackMapModel(track: mockTrack)
        
        let locations = (0..<1000).map { index in
            CLLocation(latitude: 59.3293 + Double(index) * 0.0001, longitude: 18.0686 + Double(index) * 0.0001)
        }
        
        measure {
            trackMapModel.laidPath = locations
        }
        
        XCTAssertEqual(trackMapModel.laidPath.count, 1000)
        XCTAssertGreaterThan(trackMapModel.distance, 0)
    }
}
