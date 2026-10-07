//
//  TrackTimer.swift
//  TrackPaw
//
//  Created by carl-johan.svedin on 2021-05-18.
//

import Foundation
import Observation
import os.log

enum TimerMode {
    case running
    case stopped
}

@Observable
class TrackTimer {
    @ObservationIgnored var timer = Timer()
    var secondsElapsed = 0.0
    var mode: TimerMode = .stopped

    public func start() {
        Logger.timer.debug("Starting timer")
        secondsElapsed = 0.0
        mode = .running
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.secondsElapsed += 0.1
        }
    }

    public func stop() {
        Logger.timer.debug("Stopping timer")
        timer.invalidate()
        mode = .stopped
    }

    public func resume() {
        Logger.timer.debug("Resuming timer")
        mode = .running
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.secondsElapsed += 0.1
        }
    }
}
