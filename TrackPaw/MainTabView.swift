//
//  MainTabView.swift
//  TrackPaw
//
//  Created by carl-johan.svedin on 2021-03-26.
//
import CloudKit
import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var coordinator: ViewCoordinator

    @Environment(\.preferredColorPalette) private var palette
    @AppStorage("systemTheme") private var systemTheme: Int = SchemeType.allCases.first!.rawValue
    /// Root record id from a just-accepted share, held until `.cdcksStoreDidChange`
    /// reports the import has landed and the track can be resolved.
    @State private var pendingRootRecordID: CKRecord.ID?

    private var selectedScheme: ColorScheme? {
        guard let theme = SchemeType(rawValue: systemTheme) else { return nil }
        switch theme {
        case .light:
            return .light
        case .dark:
            return .dark
        default:
            return nil
        }
    }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            TrackListView()
        }
        .foregroundColor(palette.primaryText)
        .id(palette.name)
        .tint(palette.link)
        .preferredColorScheme(selectedScheme)
        .onReceive(NotificationCenter.default.publisher(for: .didAcceptCloudKitShare)) { note in
            pendingRootRecordID = note.userInfo?["rootRecordID"] as? CKRecord.ID
        }
        .onReceive(NotificationCenter.default.storeDidChangePublisher) { _ in
            guard let rootID = pendingRootRecordID,
                  let track = PersistenceController.shared.track(forShareRoot: rootID) else { return }
            pendingRootRecordID = nil
            coordinator.path.append(Destination.editView(track: track))
        }
    }
}
