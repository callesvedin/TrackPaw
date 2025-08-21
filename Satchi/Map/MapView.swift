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

// Maybe use edge insets like https://medium.com/appcoda-tutorials/working-with-mapkit-and-annotation-for-swiftui-f7c30c4f0da6

struct MapView: View {
    let track: Track
    let preview: Bool
    let showButtons: Bool
    
    @State private var viewModel: TrackMapModel?
    @State var cameraPosition: MapCameraPosition
    @Namespace var mapScope
    @Environment(\.dismiss) var dismiss

    init(track: Track, preview: Bool = false, showButtons: Bool = true) {
        Logger.mapView.debug("Initializing MapView- Preview:\(preview)")
        self.track = track
        self.preview = preview
        self.showButtons = showButtons
        
        // Set different camera behavior based on preview mode
        if preview || track.getState() == .trailTracked {
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

    fileprivate func isPreviewOrDone() -> Bool {
        if let trackModel = self.viewModel {
            return trackModel.preview || track.getState() == .trailTracked
        }
        return true
    }
    
    var body: some View {
        Group {
            if let trackModel = self.viewModel {
                @Bindable var bindableModel = trackModel
                VStack {
                    Map(position: $cameraPosition, scope: mapScope) {
                        if !isPreviewOrDone() {
                            UserAnnotation()
                        }
                        if !bindableModel.laidCoordinates.isEmpty {
                            MapPolyline(coordinates: bindableModel.laidCoordinates)
                                .stroke(.green, lineWidth: 4)
                        }
                        if !bindableModel.trackCoordinates.isEmpty {
                            MapPolyline(coordinates: bindableModel.trackCoordinates)
                                .stroke(.red, lineWidth: 4)
                        }

                        ForEach(bindableModel.mapAnnotations) { a in
                            Marker(
                                LocalizedStringKey(a.getTitleKey()), systemImage: a.getImage(),
                                coordinate: a.getLocation()
                            ).tint(a.getColor())
                        }
                    }
                    .onChange(of: bindableModel.done) { _, done in
                        if done {
                            dismiss()
                        }
                    }
                    .mapControlVisibility(.hidden)
                    .overlay(alignment: .topTrailing) {
                        if !bindableModel.preview {
                            VStack(alignment: .trailing) {
                                if bindableModel.showAccessDenied {
                                    Image(systemName: "location.slash")
                                        .font(.title2)
                                        .foregroundColor(.red)
                                        .padding(8)
                                        .background(
                                            .regularMaterial,
                                            in: Circle()
                                        )
                                        .padding(.top, 12)
                                }
                                MapScaleView(scope: mapScope)
                                if bindableModel.isTracking {
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
                        StateButtonView(mapModel: bindableModel)
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
                        self.viewModel = TrackMapModel(track: track, preview: preview, showButtons: showButtons)
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
