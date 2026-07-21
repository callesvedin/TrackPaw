import CloudKit
import os.log
import UIKit

extension Notification.Name {
    static let didAcceptCloudKitShare = Notification.Name("didAcceptCloudKitShare")
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    /**
     To be able to accept a share, add a CKSharingSupported entry in the Info.plist file and set it to true.
     */
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        let persistenceController = PersistenceController.shared
        let sharedStore = persistenceController.sharedPersistentStore
        let container = persistenceController.persistentContainer
        container.acceptShareInvitations(from: [cloudKitShareMetadata], into: sharedStore) { _, error in
            if let error = error {
                Logger.sharing.error("\(#function): Failed to accept share invitations: \(error)")
                return
            }
            NotificationCenter.default.post(
                name: .didAcceptCloudKitShare, object: nil,
                userInfo: ["rootRecordID": cloudKitShareMetadata.hierarchicalRootRecordID as Any])
        }
    }
}
