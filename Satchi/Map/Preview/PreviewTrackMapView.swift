//
//  TrackMapView.swift
//  Satchi
//
//  Created by carl-johan.svedin on 2021-04-06.
//

import MapKit
import os.log
import SwiftUI

struct PreviewTrackMapView: View {
    @Environment(\.presentationMode) var presentationMode

    var track: Track
    var showNavigationBar: Bool

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: PreviewTrackMapView.self)
    )

    init(track: Track, showNavigationBar: Bool) {
        self.track = track
        self.showNavigationBar = showNavigationBar
    }

    var body: some View {
        PreviewMapView(
            laidPath: track.laidPath,
            trackPath: track.trackPath,
            allowUserInteraction: self.showNavigationBar
        )
            .navigationBarHidden(!self.showNavigationBar)
            .ignoresSafeArea()
    }
}

//
// struct PreviewTrackMapView_Previews: PreviewProvider {
//    static var previews: some View {
//        let stack = CoreDataStack.preview
//
//        NavigationView {
//            PreviewTrackMapView(track: stack.getTracks()[0])
//                .environmentObject(CoreDataStack.preview)
//        }
//    }
// }
