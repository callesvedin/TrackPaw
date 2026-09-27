//
//  TrackPawTests.swift
//  TrackPawTests
//
//  Created by carl-johan.svedin on 2021-03-25.
//

import XCTest
import SwiftUI
import UIKit
@testable import TrackPaw

class TrackPawTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func test_allPaletteColorsResolve() {
        let names = [
            "accent", "background-alt", "background-main", "background-mid", "link",
            "primary", "quaternary", "secondary", "tertiary", "text-alt", "text-primary"
        ]
        for name in names {
            XCTAssertNotNil(UIColor(named: "TrackPaw/\(name)"), "Missing colour TrackPaw/\(name)")
        }
        XCTAssertEqual(Color.Palette.trackPaw.name, "TrackPaw")
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
