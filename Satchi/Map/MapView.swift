//
//  SwiftUIView.swift
//  Satchi
//
//  Created by Carl-Johan Svedin on 2023-09-21.
//

import MapKit
import SwiftUI
import Combine
import os.log

class OptionalTrackMapModel: ObservableObject {
    @Published var trackModel: TrackMapModel? {
        didSet {
            // Re-publish any changes from the nested trackModel
            if let trackModel = trackModel {
                trackModel.objectWillChange.sink { [weak self] _ in
                    self?.objectWillChange.send()
                }.store(in: &cancellables)
            }
        }
    }
    private var cancellables: Set<AnyCancellable> = []
}

// Maybe use edge insets like https://medium.com/appcoda-tutorials/working-with-mapkit-and-annotation-for-swiftui-f7c30c4f0da6

struct MapView: View {
    let track: Track
    let preview: Bool
    let showButtons: Bool
    
    @StateObject private var modelHolder = OptionalTrackMapModel()
    @State var cameraPosition: MapCameraPosition
    @Namespace var mapScope
    @Environment(\.dismiss) var dismiss

    init(track: Track, preview: Bool = false, showButtons: Bool = true) {
        Logger.mapView.debug("Initializing MapView- Preview:\(preview)")
        self.track = track
        self.preview = preview
        self.showButtons = showButtons
        
        // Set different camera behavior based on preview mode
        if preview {
            self._cameraPosition = State(initialValue: .automatic)
        } else {
            self._cameraPosition = State(
                initialValue: .userLocation(fallback: MapCameraPosition.automatic))
        }
    }
    
//    // Convenience init for existing TrackMapModel (for compatibility)
//    init(trackModel: TrackMapModel) {
//        self.track = trackModel.track
//        self.preview = trackModel.preview
//        self.showButtons = trackModel.showButtons
//        self._trackModel = State(initialValue: trackModel)
//        
//        // Set different camera behavior based on preview mode
//        if trackModel.preview {
//            self._cameraPosition = State(initialValue: .automatic)
//        } else {
//            self._cameraPosition = State(
//                initialValue: .userLocation(fallback: MapCameraPosition.automatic))
//        }
//    }

    var body: some View {
        Group {
            if let trackModel = modelHolder.trackModel {
                VStack {
                    Map(position: $cameraPosition, scope: mapScope) {
                        if !trackModel.preview {
                            UserAnnotation()
                        }
                        if !trackModel.laidCoordinates.isEmpty {
                            MapPolyline(coordinates: trackModel.laidCoordinates)
                                .stroke(.green, lineWidth: 4)
                        }
                        if !trackModel.trackCoordinates.isEmpty {
                            MapPolyline(coordinates: trackModel.trackCoordinates)
                                .stroke(.red, lineWidth: 4)
                        }

                        ForEach(trackModel.mapAnnotations) { a in
                            Marker(
                                LocalizedStringKey(a.getTitleKey()), systemImage: a.getImage(),
                                coordinate: a.getLocation()
                            ).tint(a.getColor())
                        }
                    }
                    .onChange(of: trackModel.done) { _, done in
                        if done {
                            dismiss()
                        }
                    }
                    .mapControlVisibility(.hidden)
                    .overlay(alignment: .topTrailing) {
                        if !trackModel.preview {
                            VStack(alignment: .trailing) {
                                MapScaleView(scope: mapScope)
                                if trackModel.isTracking {
                                    MapUserLocationButton(scope: mapScope)
                                }
                                MapCompass(scope: mapScope)
                            }
                            .padding(.top, 40)
                            .padding(.trailing, 20)
                            .buttonBorderShape(.roundedRectangle)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        StateButtonView(mapModel: trackModel)
                            .padding(.bottom, 30)
                    }
                    .mapStyle(.imagery(elevation: .flat))
                    .mapScope(mapScope)
                }
                .navigationBarHidden(true)
                .navigationBarBackButtonHidden(true)
                .ignoresSafeArea(.all)
                .tint(.blue)
            } else {
                Color.clear
                    .onAppear {
                        modelHolder.trackModel = TrackMapModel(track: track, preview: preview, showButtons: showButtons)
                    }
            }
        }
    }
}

#Preview {
    let track = Track(context: PersistenceController.shared.persistentContainer.viewContext)
    track.name = "Test-Track"
    track.created = Date()
    track.timeToFinish = 19 * 60
    track.difficulty = 3
    track.comments = "A little test..."
    track.timeToCreate = 21 * 60
    track.started = Date().addingTimeInterval(60 * 60 * 3)
    track.length = 1000
    track.laidPath = [
        CLLocation(latitude: CLLocationDegrees(56.65422), longitude: CLLocationDegrees(16.32646)),
        CLLocation(latitude: CLLocationDegrees(56.65422), longitude: CLLocationDegrees(16.32446)),
        CLLocation(latitude: CLLocationDegrees(56.65622), longitude: CLLocationDegrees(16.32446))
    ]
    track.trackPath = [
        CLLocation(latitude: CLLocationDegrees(56.65432), longitude: CLLocationDegrees(16.32649)),
        CLLocation(latitude: CLLocationDegrees(56.65420), longitude: CLLocationDegrees(16.32453)),
        CLLocation(latitude: CLLocationDegrees(56.65622), longitude: CLLocationDegrees(16.32446))
    ]
    return MapView(track: track)
}
