//
//  Logger.swift
//  TrackPaw
//
//  Created by Carl-Johan Svedin on 2023-03-21.
//

import Foundation
import os.log

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!

    static let mapView = Logger(subsystem: subsystem, category: "MapView")
    static let trackPawApp = Logger(subsystem: subsystem, category: "TrackPawApp")
    static let sharing = Logger(subsystem: subsystem, category: "Sharing")
    static let timer = Logger(subsystem: subsystem, category: "Timer")
    static let persistance = Logger(subsystem: subsystem, category: "Persistance")
    static let listView = Logger(subsystem: subsystem, category: "ListView")

}
