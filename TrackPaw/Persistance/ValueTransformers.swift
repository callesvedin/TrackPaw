//
//  ValueTransformers.swift
//  TrackPaw
//
//  Created by Carl-Johan Svedin on 2023-03-21.
//

import CoreLocation
import Foundation

@objc(CLLocationArrayTransformer)
class CLLocationArrayTransformer: NSSecureUnarchiveFromDataTransformer {

    override class var allowedTopLevelClasses: [AnyClass] {
        return super.allowedTopLevelClasses + [NSArray.self, CLLocation.self]
    }

    override class func allowsReverseTransformation() -> Bool {
        return true
    }

    override class func transformedValueClass() -> AnyClass {
        return NSData.self
    }
}

extension CLLocationArrayTransformer {
    class func register() {
        CLLocationArrayTransformer.setValueTransformer(
            CLLocationArrayTransformer(),
            forName: NSValueTransformerName("CLLocationArrayTransformer")
        )
    }
}
