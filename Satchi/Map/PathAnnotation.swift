//
//  StartAnnotation.swift
//  Satchi
//
//  Created by carl-johan.svedin on 2021-04-14.
//

import Foundation
import SwiftUI
import MapKit

enum PathAnnotationKind: Hashable
{

    func hash(into hasher: inout Hasher) {

        hasher.combine(self.getTitle())
//        switch self {
//        case .trailStart(let value):
//            hasher.combine(value.longitude)
//            hasher.combine(value.latitude)
//        case .trailEnd(let value):
//            hasher.combine(value.longitude)
//            hasher.combine(value.latitude)
//        case .trackingStart(let value):
//            hasher.combine(value.longitude)
//            hasher.combine(value.latitude)
//        case .trackingEnd(let value):
//            hasher.combine(value.longitude)
//            hasher.combine(value.latitude)
//        case .dummy(let value):
//            hasher.combine(value.longitude)
//            hasher.combine(value.latitude)
//        }
    }

    static func == (lhs: PathAnnotationKind, rhs: PathAnnotationKind) -> Bool {
        return lhs.getTitle() == rhs.getTitle()
    }

    case trailStart(location: CLLocationCoordinate2D),
         trailEnd(location: CLLocationCoordinate2D),
         trackingStart(location: CLLocationCoordinate2D),
         trackingEnd(location: CLLocationCoordinate2D),
         dummy(location: CLLocationCoordinate2D)

    func getTitle() -> String {
        switch self {
        case .trailStart:
            return "Start"
        case .trailEnd:
            return "Stop"
        case .trackingStart:
            return "Track Start"
        case .trackingEnd:
            return "Track Stop"
        case .dummy:
            return "Dummy"
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
