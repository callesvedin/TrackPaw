import CloudKit
import CoreData
import CoreTransferable
import Foundation
import os.log

protocol TrackSharing {
    func sharingInfo(for track: Track) -> TrackSharingInfo
    func share(for track: Track) -> CKShare?
    func invalidate()
}

/// Owns all sharing lookups. Caches by objectID and clears the cache whenever a
/// store changes, so views can call `sharingInfo(for:)` cheaply during layout.
final class TrackSharingService: TrackSharing {
    static let shared = TrackSharingService()

    private let controller: PersistenceController
    private var infoCache: [NSManagedObjectID: TrackSharingInfo] = [:]
    private var shareCache: [NSManagedObjectID: CKShare] = [:]
    private let lock = NSLock()
    /// Bumped under `lock` on every `invalidate()`. Lets in-flight lookups that
    /// started before an invalidation detect it and skip their stale write-back.
    private var generation = 0

    init(controller: PersistenceController = .shared) {
        self.controller = controller
        NotificationCenter.default.addObserver(
            self, selector: #selector(storeChanged),
            name: .NSPersistentStoreRemoteChange, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(storeChanged),
            name: .cdcksStoreDidChange, object: nil)
    }

    @objc private func storeChanged() { invalidate() }

    func invalidate() {
        lock.lock(); defer { lock.unlock() }
        generation += 1
        infoCache.removeAll()
        shareCache.removeAll()
    }

    func share(for track: Track) -> CKShare? {
        lock.lock()
        if let cached = shareCache[track.objectID] { lock.unlock(); return cached }
        let gen = generation
        lock.unlock()

        guard let shares = try? controller.persistentContainer
            .fetchShares(matching: [track.objectID]),
              let share = shares.first?.value else { return nil }

        lock.lock()
        if generation == gen { shareCache[track.objectID] = share }
        lock.unlock()
        return share
    }

    func sharingInfo(for track: Track) -> TrackSharingInfo {
        lock.lock()
        if let cached = infoCache[track.objectID] { lock.unlock(); return cached }
        let gen = generation
        lock.unlock()

        let facts = facts(for: track)
        let info = TrackSharingInfo(facts: facts)

        lock.lock()
        if generation == gen { infoCache[track.objectID] = info }
        lock.unlock()
        return info
    }

    private func facts(for track: Track) -> TrackSharingFacts {
        let storeKind: TrackStoreKind
        if let store = track.persistentStore {
            storeKind = (store == controller.sharedPersistentStore)
                ? .sharedStore : .privateStore
        } else {
            storeKind = .notPersisted
        }

        let ckShare = share(for: track)
        return TrackSharingFacts(
            storeKind: storeKind,
            isShared: ckShare != nil,
            ownerName: ckShare.flatMap { Self.name(for: $0.owner) },
            participantNames: ckShare.map { s in
                s.participants
                    .filter { $0.role != .owner && $0.acceptanceStatus == .accepted }
                    .compactMap { Self.name(for: $0) }
            } ?? [])
    }

    private static func name(for participant: CKShare.Participant) -> String? {
        guard let components = participant.userIdentity.nameComponents else { return nil }
        let name = PersonNameComponentsFormatter().string(from: components)
        return name.isEmpty ? nil : name
    }
}

extension TrackSharingService {
    /// Create (or reuse) a CKShare for the track. Wraps the completion-based
    /// NSPersistentCloudKitContainer API so `ShareLink` can await it.
    func prepareShare(for track: Track) async throws -> CKShare {
        if let existing = share(for: track) { return existing }
        return try await withCheckedThrowingContinuation { continuation in
            controller.persistentContainer.share([track], to: nil) { _, share, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let share = share {
                    share[CKShare.SystemFieldKey.title] = track.name as CKRecordValue
                    self.controller.persistentContainer.persistUpdatedShare(share, in: self.controller.privatePersistentStore) { persisted, persistError in
                        if let persistError = persistError {
                            Logger.sharing.error("\(#function): Failed to persist share title: \(persistError)")
                        }
                        self.invalidate()
                        continuation.resume(returning: persisted ?? share)
                    }
                } else {
                    continuation.resume(throwing: CKError(.internalError))
                }
            }
        }
    }

    func makeTransferable(for track: Track) -> TrackShareTransferable {
        TrackShareTransferable(
            existingShare: share(for: track),
            container: controller.cloudKitContainer,
            prepare: { [weak self] in
                guard let self else { throw CKError(.internalError) }
                return try await self.prepareShare(for: track)
            })
    }
}

extension TrackSharingService {
    /// Participant leaves a share: purge the local copy in the shared store.
    /// The owner's track is untouched.
    func removeSelf(from track: Track) async throws {
        guard let share = share(for: track) else { return }
        _ = try await controller.persistentContainer.purgeObjectsAndRecordsInZone(
            with: share.recordID.zoneID, in: controller.sharedPersistentStore)
        invalidate()
    }
}

struct TrackShareTransferable: Transferable {
    let existingShare: CKShare?
    let container: CKContainer
    let prepare: () async throws -> CKShare

    static var transferRepresentation: some TransferRepresentation {
        CKShareTransferRepresentation { item in
            if let share = item.existingShare {
                return .existing(share, container: item.container,
                                 allowedSharingOptions: .standard)
            }
            return .prepareShare(container: item.container,
                                 allowedSharingOptions: .standard) {
                try await item.prepare()
            }
        }
    }
}
