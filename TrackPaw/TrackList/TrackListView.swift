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
    @State private var trackToShare: Track?
    @State private var showICloudAlert = false
    @State private var didFlagICloudUnavailable = false

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
        content
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
            .accessibilityIdentifier("addTrackButton")
        }
        .onReceive(NotificationCenter.default.storeDidChangePublisher) { notification in
            processStoreChangeNotification(notification)
        }
        .onChange(of: persistenceController.isCloudAvailable, initial: true) { _, available in
            if !available && !didFlagICloudUnavailable {
                didFlagICloudUnavailable = true
                showICloudAlert = true
            }
        }
        .alert("Not signed in to iCloud", isPresented: $showICloudAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Sign in to iCloud to share tracks.")
        }
        .alert(
            "Sync issue",
            isPresented: Binding(
                get: { syncMonitor.lastUserFacingError != nil },
                set: { if !$0 { syncMonitor.lastUserFacingError = nil } }
            ),
            presenting: syncMonitor.lastUserFacingError
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { message in
            Text(message)
        }
        .preferredColorScheme(selectedScheme)
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
                                .accessibilityIdentifier("trackCell")
                                .swipeActions(allowsFullSwipe: false) {
                                    if persistenceController.isCloudAvailable {
                                        Button {
                                            trackToShare = track
                                        } label: {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                        }
                                        .tint(.green)
                                    }
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
                .sheet(item: $trackToShare) { track in
                    ShareTrackSheet(track: track)
                }
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
