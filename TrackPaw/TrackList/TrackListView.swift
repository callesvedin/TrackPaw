//
//  ContentView.swift
//  TrackPaw
//
//  Created by carl-johan.svedin on 2021-03-25.
//

import CloudKit
import CoreData
import SwiftUI
import os.log

struct TrackListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var environment: AppEnvironment
    @EnvironmentObject var coordinator: ViewCoordinator
    @EnvironmentObject var syncMonitor: SyncMonitor
    @Environment(\.preferredColorPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    @SectionedFetchRequest(
        sectionIdentifier: \Track.state,
        sortDescriptors: [
            SortDescriptor(\Track.state, order: .forward),
            SortDescriptor(\Track.created, order: .reverse),
            SortDescriptor(\Track.name, order: .forward)
        ],
        animation: Animation.default
    )
    private var tracks: SectionedFetchResults<Int16, Track>
    @ObservedObject private var persistenceController = PersistenceController.shared

    @AppStorage("systemTheme") private var systemTheme: Int = SchemeType.allCases.first!.rawValue

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
        VStack(spacing: 0) {
            banners
            content
        }
        .foregroundColor(palette.primaryText)
        .navigationTitle(LocalizedStringKey("Tracks"))
        .overlay(alignment: .bottomTrailing) {
            Button {
                createNewTrack()
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .padding(6)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .tint(palette.accent)
            .padding(24)
            .accessibilityLabel(Text("Add track"))
        }
        .onReceive(NotificationCenter.default.storeDidChangePublisher) { notification in
            processStoreChangeNotification(notification)
        }.preferredColorScheme(selectedScheme)
    }

    @ViewBuilder
    private var banners: some View {
        if !persistenceController.isCloudAvailable {
            banner(Text("Sign in to iCloud to share tracks."))
        }
        if let message = syncMonitor.lastUserFacingError {
            banner(Text(message), dismissAction: { syncMonitor.lastUserFacingError = nil })
        }
    }

    @ViewBuilder
    private func banner(_ text: Text, dismissAction: (() -> Void)? = nil) -> some View {
        HStack {
            text
                .font(.footnote)
            Spacer()
            if let dismissAction {
                Button(action: dismissAction) {
                    Image(systemName: "xmark.circle.fill")
                }
                .accessibilityLabel(Text("Dismiss"))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(palette.warning.opacity(0.15))
        .foregroundColor(palette.primaryText)
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            palette.mainBackground.ignoresSafeArea(.all)
            if tracks.isEmpty {
                NoTracksView(callback: createNewTrack)
            } else {
                List {
                    ForEach(tracks) { section in
                        Section(
                            header: Text(
                                LocalizedStringKey(TrackState(rawValue: section.id)!.text()))
                        ) {
                            ForEach(section, id: \.id) { track in
                                Button(
                                    action: {
                                        Logger.listView.debug("Adding destination")
                                        coordinator.path.append(Destination.editView(track: track))
                                    },
                                    label: {
                                        TrackCellView(
                                            deleteFunction: deleteTrack,
                                            track: track)
                                    }
                                )
                                .swipeActions(allowsFullSwipe: false) {
                                    shareLink(for: track)
                                    Button(role: .destructive) {
                                        deleteTrack(track)
                                    } label: {
                                        Label("Delete", systemImage: "trash.fill")
                                    }
                                    .tint(.red)
                                }
                            }
                        }
                        .headerProminence(.increased)
                    }
                    .listRowBackground(palette.midBackground)
                }
                .listStyle(.automatic)
                .hideScroll()
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .editView(let track):
                        EditTrackView(track)
                    case .runView(let track):
                        MapView(track: track)
                        .onDisappear{
                            if track.length == 0 {
                                deleteTrack(track)
                                coordinator.pop()
                            }
                        }
                    }
                }
            }
        }
    }

    private func createNewTrack() {
        let trackName = TimeFormatter.dayDateStringFrom(date: Date())
        if let track = persistenceController.addTrack(name: trackName, context: viewContext) {
            coordinator.path.append(Destination.editView(track: track))
            coordinator.path.append(Destination.runView(track: track))
        } else {
            Logger.listView.warning("Could not create a new track when add button pushed.")
        }
    }

    private func processStoreChangeNotification(_ notification: Notification) {
        let transactions = persistenceController.trackTransactions(from: notification)
        if !transactions.isEmpty {
            persistenceController.mergeTransactions(transactions, to: viewContext)
        }
    }

    func deleteTrack(_ track: Track) {
        PersistenceController.shared.delete(track: track)
    }

    @ViewBuilder
    private func shareLink(for track: Track) -> some View {
        if persistenceController.isCloudAvailable {
            ShareLink(item: TrackSharingService.shared.makeTransferable(for: track),
                      preview: SharePreview(track.name)) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .tint(.green)
        } else {
            Button {
                // No-op: sharing requires iCloud, disabled below.
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .tint(.gray)
            .disabled(true)
        }
    }
}

struct HideScrollModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.scrollContentBackground(.hidden)
    }
}

extension View {
    func hideScroll() -> some View {
        modifier(HideScrollModifier())
    }
}

struct NoTracksView: View {
    @Environment(\.preferredColorPalette) private var palette
    var callback: () -> Void
    var body: some View {
        VStack {
            Spacer()
            Text("You have no tracks.")
            Button("Add track") {
                callback()
            }
            .foregroundColor(palette.link)
            Spacer()
        }
    }
}
