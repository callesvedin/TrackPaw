import CloudKit

/// CloudKit sharing/sync require a signed-in, available iCloud account.
/// Only `.available` qualifies; every other status (including the transient
/// `.temporarilyUnavailable` and `.couldNotDetermine`) means "treat as
/// unavailable" for the purpose of gating the Share UI.
func isCloudAvailable(from status: CKAccountStatus) -> Bool {
    status == .available
}
