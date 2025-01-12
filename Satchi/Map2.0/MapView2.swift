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
    @State var cameraPosition: MapCameraPosition = .userLocation(fallback: MapCameraPosition.automatic)
    @Namespace var mapScope

    var body: some View {
        VStack {
            Map(position: $cameraPosition, scope: mapScope){
                if !trackModel.laidCoordinates.isEmpty {
                    MapPolyline(coordinates: trackModel.laidCoordinates)
                        .stroke(.green, lineWidth: 4)
                }
                if !trackModel.trackCoordinates.isEmpty {
                    MapPolyline(coordinates: trackModel.trackCoordinates)
                        .stroke(.red, lineWidth: 4)
                }

                ForEach(trackModel.mapAnnotations) {a in
                    Marker(a.getTitle(), systemImage: a.getImage(), coordinate: a.getLocation()).tint(a.getColor())
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
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .ignoresSafeArea(.all)
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
        CLLocation(latitude: CLLocationDegrees(56.65420), longitude: CLLocationDegrees(16.32453)),
        CLLocation(latitude: CLLocationDegrees(56.65622), longitude: CLLocationDegrees(16.32446))
    ]
    return MapView2(trackModel: TrackMapModel(track: track))
}
