import XCTest
import CoreData
@testable import TrackPaw

final class TrackSharingTests: XCTestCase {

    private func makeContext() -> NSManagedObjectContext {
        PersistenceController.shared.persistentContainer.viewContext
    }

    func test_trackerComments_isSeparateFromComments_andCloned() throws {
        let context = makeContext()
        let track = Track(context: context, name: "Model Test", id: UUID())
        track.comments = "owner note"
        track.trackerComments = "dog lost scent at corner"

        let copy = track.clone(with: context)

        XCTAssertEqual(track.comments, "owner note")
        XCTAssertEqual(track.trackerComments, "dog lost scent at corner")
        XCTAssertEqual(copy.comments, "owner note")
        XCTAssertEqual(copy.trackerComments, "dog lost scent at corner")

        context.delete(track)
        context.delete(copy)
        try? context.save()
    }
}
