import XCTest
import CloudKit
@testable import TrackPaw

final class CloudAvailabilityTests: XCTestCase {
    func test_onlyAvailableStatusMeansCloudAvailable() {
        XCTAssertTrue(isCloudAvailable(from: .available))
        XCTAssertFalse(isCloudAvailable(from: .noAccount))
        XCTAssertFalse(isCloudAvailable(from: .restricted))
        XCTAssertFalse(isCloudAvailable(from: .couldNotDetermine))
        XCTAssertFalse(isCloudAvailable(from: .temporarilyUnavailable))
    }
}
