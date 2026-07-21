/*
 See LICENSE folder for this sample’s licensing information.

 Abstract:
 Extensions that wrap the related methods for sharing.
 */

import CloudKit
import CoreData
import Foundation
import os.log

extension PersistenceController {
    /// Best-effort lookup of the `Track` a just-accepted share resolves to. Matches
    /// by record zone since the imported track's own record id isn't known upfront;
    /// call again on each `.cdcksStoreDidChange` until the CloudKit import lands.
    func track(forShareRoot recordID: CKRecord.ID) -> Track? {
        let request = Track.fetchRequest()
        request.affectedStores = [sharedPersistentStore]
        let tracks: [Track]
        do {
            tracks = try persistentContainer.viewContext.fetch(request)
        } catch {
            Logger.sharing.error("\(#function): Failed to fetch shared-store tracks: \(error)")
            return nil
        }
        return tracks.first { track in
            do {
                let shares = try persistentContainer.fetchShares(matching: [track.objectID])
                return shares.first?.value.recordID.zoneID == recordID.zoneID
            } catch {
                Logger.sharing.error("\(#function): Failed to fetch shares for track: \(error)")
                return false
            }
        }
    }
}
