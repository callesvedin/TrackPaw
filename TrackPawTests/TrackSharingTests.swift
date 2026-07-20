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

    func test_notPersisted_isOwner_notShared_canEdit() {
        let info = TrackSharingInfo(facts: .init(
            storeKind: .notPersisted, isShared: false,
            ownerName: nil, participantNames: []))
        XCTAssertEqual(info.role, .owner)
        XCTAssertEqual(info.status, .notShared)
        XCTAssertTrue(info.canEditMetadata)
    }

    func test_privateStoreShared_isOwner_sharedByMe_canEdit() {
        let info = TrackSharingInfo(facts: .init(
            storeKind: .privateStore, isShared: true,
            ownerName: "Me", participantNames: ["Alex"]))
        XCTAssertEqual(info.role, .owner)
        XCTAssertEqual(info.status, .sharedByMe)
        XCTAssertTrue(info.canEditMetadata)
        XCTAssertEqual(info.participantNames, ["Alex"])
    }

    func test_sharedStore_isParticipant_sharedWithMe_cannotEdit() {
        let info = TrackSharingInfo(facts: .init(
            storeKind: .sharedStore, isShared: true,
            ownerName: "Owner", participantNames: []))
        XCTAssertEqual(info.role, .participant)
        XCTAssertEqual(info.status, .sharedWithMe)
        XCTAssertFalse(info.canEditMetadata)
        XCTAssertEqual(info.ownerName, "Owner")
    }
}
