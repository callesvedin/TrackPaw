//
//  StartAnnotation.swift
//  Satchi
//
//  Created by carl-johan.svedin on 2021-04-14.
//

import Foundation
import SwiftUI
import MapKit

enum PathAnnotationKind: Hashable, Identifiable
{

    var id: String { getTitleKey() }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.getTitleKey())
    }

    static func == (lhs: PathAnnotationKind, rhs: PathAnnotationKind) -> Bool {
        return lhs.getTitleKey() == rhs.getTitleKey()
    }

    case trailStart(location: CLLocationCoordinate2D),
         trailEnd(location: CLLocationCoordinate2D),
         trackingStart(location: CLLocationCoordinate2D),
         trackingEnd(location: CLLocationCoordinate2D),
         dummy(location: CLLocationCoordinate2D)

    func getLocation() -> CLLocationCoordinate2D {
        switch self {
        case .trailStart(let location):
            return location
        case .trailEnd(let location):
            return location
        case .trackingStart(let location):
            return location
        case .trackingEnd(let location):
            return location
        case .dummy(let location):
            return location
        }
    }

    func getTitleKey() -> String {
        switch self {
        case .trailStart:
            return "laidStart" // return "Start" // String(localized: "laidStart")
        case .trailEnd:
            return "laidStop" // return "Stop" // String(localized: "laidStop")
        case .trackingStart:
            return "trackStart" // "Start" //
        case .trackingEnd:
            return "trackStop" // "Stop" //
        case .dummy:
            return String(localized: "Dummy") // "Dummy" // String(localized: "Dummy")
        }
    }

    func getImage() -> String {
        switch self {
        case .trailStart:
            return "signpost.right.circle"
        case .trailEnd:
            return "signpost.right.circle"
        case .trackingStart:
            return "figure.walk.circle"
        case .trackingEnd:
            return "figure.walk.circle"
        case .dummy:
            return "rosette"
        }
    }

    func getColor() -> Color {
        switch self {
        case .trailStart:
            return Color(.green)
        case .trailEnd:
            return Color(.green)
        case .trackingStart:
            return Color(.red)
        case .trackingEnd:
            return Color(.red)
        case .dummy:
            return Color(.magenta)
        }
    }
}
