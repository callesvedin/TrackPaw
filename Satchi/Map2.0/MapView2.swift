//
//  SwiftUIView.swift
//  Satchi
//
//  Created by Carl-Johan Svedin on 2023-09-21.
//

import MapKit
import SwiftUI
// Maybe use edge insets like https://medium.com/appcoda-tutorials/working-with-mapkit-and-annotation-for-swiftui-f7c30c4f0da6

struct MapView2: View {
    @StateObject var trackModel: TrackMapModel
    @Namespace var mapScope

    var body: some View {
//        ZStack {
            Map(scope: mapScope) {
                // I must change this to add all PathAnnotations from trackModel
                if let location = trackModel.trailStartLocation {
                    Marker("Start", systemImage: "signpost.right.circle", coordinate: location).tint(.green)
                }

                if let location = trackModel.trailEndLocation {
                    Marker("End", systemImage: "signpost.right.circle", coordinate: location).tint(.green)
                }

                if let location = trackModel.trackStartLocation {
                    Marker("Start", systemImage: "figure.walk.circle", coordinate: location).tint(.red)
                }

                if let location = trackModel.trackEndLocation {
                    Marker("End", systemImage: "figure.walk.circle", coordinate: location).tint(.red)
                }

                if !trackModel.laidCoordinates.isEmpty {
                    MapPolyline(coordinates: trackModel.laidCoordinates)
                        .stroke(.green, lineWidth: 4)
                }
                if !trackModel.trackCoordinates.isEmpty {
                    MapPolyline(coordinates: trackModel.trackCoordinates)
                        .stroke(.red, lineWidth: 4)
                }
            }
            .overlay(alignment: .topTrailing) {
                VStack {
                    MapUserLocationButton(scope: mapScope)
                    MapCompass(scope: mapScope).mapControlVisibility(.automatic)
                    //                    MapScaleView(scope: mapScope)
                }
                .padding(.top, 40)
                .padding(.trailing, 20)
                .buttonBorderShape(.roundedRectangle)
            }
            .overlay(alignment: .bottom){
                StateButtonView(mapModel: trackModel)
                                    .padding(.bottom, 30)
            }
            .mapStyle(.imagery(elevation: .flat))
            .mapScope(mapScope)
    }
}

#Preview {
    let track = Track(context: PersistenceController.shared.persistentContainer.viewContext)
    track.name = "Test-Track"
    track.created = Date()
    track.timeToFinish = 19*60
    track.difficulty = 3
    track.comments = "A little test..."
    track.timeToCreate = 21*60
    track.started = Date().addingTimeInterval(60*60*3)
    track.length = 1000
    track.laidPath = [
        CLLocation(latitude: CLLocationDegrees(56.65422), longitude: CLLocationDegrees(16.32646)),
        CLLocation(latitude: CLLocationDegrees(56.65422), longitude: CLLocationDegrees(16.32446)),
        CLLocation(latitude: CLLocationDegrees(56.65622), longitude: CLLocationDegrees(16.32446))
    ]
    track.trackPath = [
        CLLocation(latitude: CLLocationDegrees(56.65432), longitude: CLLocationDegrees(16.32649)),
        CLLocation(latitude: CLLocationDegrees(56.65420), longitude: CLLocationDegrees(16.32443)),
        CLLocation(latitude: CLLocationDegrees(56.65622), longitude: CLLocationDegrees(16.32446))
    ]
    return MapView2(trackModel: TrackMapModel(track: track))
}
