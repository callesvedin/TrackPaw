import CloudKit
import CoreData
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
