import Foundation

/// Whether the current user owns this track or is following someone else's.
enum TrackRole: Equatable {
    case owner
    case participant
}

/// Which persistent store the track lives in. Drives role derivation.
enum TrackStoreKind: Equatable {
    case privateStore
    case sharedStore
    case notPersisted
}

/// CloudKit-free inputs gathered by `TrackSharingService`, kept primitive so the
/// reduction below is unit-testable without a live iCloud account.
struct TrackSharingFacts: Equatable {
    var storeKind: TrackStoreKind
    var isShared: Bool
    var ownerName: String?
    var participantNames: [String]
}

/// The sharing state the UI renders from.
struct TrackSharingInfo: Equatable {
    enum Status: Equatable { case notShared, sharedByMe, sharedWithMe }

    let role: TrackRole
    let status: Status
    let ownerName: String?
    let participantNames: [String]

    /// Only the owner may edit name/comments/difficulty, re-lay, or delete.
    var canEditMetadata: Bool { role == .owner }

    init(facts: TrackSharingFacts) {
        role = (facts.storeKind == .sharedStore) ? .participant : .owner
        if !facts.isShared {
            status = .notShared
        } else {
            status = (role == .owner) ? .sharedByMe : .sharedWithMe
        }
        ownerName = facts.ownerName
        participantNames = facts.participantNames
    }

    static let notShared = TrackSharingInfo(
        facts: .init(storeKind: .notPersisted, isShared: false,
                     ownerName: nil, participantNames: []))
}
