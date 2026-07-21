//
//  EditTrackView.swift
//  TrackPaw
//
//  Created by carl-johan.svedin on 2021-04-05.
//

import CloudKit
import CoreData
import SwiftUI

struct EditTrackView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.preferredColorPalette) private var palette
    @EnvironmentObject var coordinator: ViewCoordinator
    @ObservedObject var theTrack: Track
    @State private var showingDeleteAlert = false
    @State private var mapRefreshTrigger = 0
    private var persistanceController = PersistenceController.shared

    init(_ track: Track) {
        theTrack = track
    }

    var actionsMenu: some View {
        Menu {
            ShareLink(item: TrackSharingService.shared
                .makeTransferable(for: theTrack),
                preview: SharePreview(theTrack.name)) {
                Label("Share Track", systemImage: "square.and.arrow.up")
            }

            if TrackSharingService.shared
                .sharingInfo(for: theTrack).canEditMetadata {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete Track", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    Task {
                        try? await TrackSharingService.shared
                            .removeSelf(from: theTrack)
                        dismiss()
                    }
                } label: {
                    Label("Remove me from shared track", systemImage: "person.badge.minus")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .tint(palette.link)
    }

    @ViewBuilder
    var showMapViewButton: some View {
        switch theTrack.getState() {
        case .trailTracked:
            Button {
                coordinator.path.append(Destination.runView(track: theTrack))
            } label: {
                Text("Show track")
            }
        case .notStarted:
            Button {
                coordinator.path.append(Destination.runView(track: theTrack))
            }label: {
                Text("Lay track")
            }
        default:
            Button {
                coordinator.path.append(Destination.runView(track: theTrack))
            }label: {
                Text("Follow track")
            }

        }
    }

    var body: some View {
        Form {
            Section {
                MapView(track: theTrack, preview: true, showButtons: false)
                    .id(mapRefreshTrigger)
                    .scaledToFit()
                    .cornerRadius(10)
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            FieldsView(theTrack: theTrack,
                       canEdit: TrackSharingService.shared
                        .sharingInfo(for: theTrack).canEditMetadata)
                .listRowBackground(palette.midBackground)
        }
        .scrollContentBackground(.hidden)
        .foregroundColor(palette.primaryText)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                showMapViewButton
                    .buttonStyle(.glassProminent)
                    .tint(palette.accent)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                actionsMenu.foregroundStyle(palette.link)
            }
        }
        .background(palette.mainBackground)
        .navigationBarTitle(theTrack.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
        .navigationBarBackButtonHidden(false)
        .onChange(of: theTrack.state) { _, _ in
            mapRefreshTrigger += 1
        }
        .alert("Delete Track", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteTrack()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(String(localized: "delete.confirmation"))
        }
        .onAppear {
            mapRefreshTrigger += 1
        }
        .onDisappear {
            if theTrack.length > 0 {
                Task {
                    await persistanceController.updateTrack(track: theTrack)
                }
            }
        }
    }

    private func deleteTrack() {
        persistanceController.delete(track: theTrack)
        dismiss()
    }
}

struct FieldsView: View {
    @ObservedObject var theTrack: Track
    var canEdit: Bool = true

    var body: some View {
        Section("Name") {
            TextField("Name", text: $theTrack.name)
                .font(.title2)
                .disabled(!canEdit)
        }

        Section {
            LabeledContent(
                "Created:",
                value: theTrack.created != nil ? TimeFormatter.dateStringFrom(date: theTrack.created) : "-"
            )
            LabeledContent(
                "Time to create:",
                value: TimeFormatter.shortTimeWithSecondsFor(seconds: theTrack.timeToCreate)
            )
            LabeledContent(
                "Time since created:",
                value: getTimeSinceCreated()
            )
            LabeledContent(
                "Length:",
                value: DistanceFormatter.distanceFor(meters: Double(theTrack.length))
            )
            LabeledContent("Difficulty:") {
                DifficultyView(difficulty: $theTrack.difficulty)
                    .disabled(!canEdit)
                    // DifficultyView taps its own onTapGesture, which .disabled()
                    // doesn't block on its own — allowsHitTesting does.
                    .allowsHitTesting(canEdit)
                    .opacity(canEdit ? 1 : 0.4)
            }
            LabeledContent(
                "Track rested:",
                value: getTimeBetween(date: theTrack.created, and: theTrack.started)
            )
            LabeledContent(
                "Tracking started:",
                value: theTrack.started != nil ? TimeFormatter.dateStringFrom(date: theTrack.started!) : "-"
            )
            LabeledContent(
                "Time to finish:",
                value: theTrack.timeToFinish > 0 ? TimeFormatter.shortTimeWithSecondsFor(seconds: theTrack.timeToFinish) : "-"
            )
        }

        Section("Comments") {
            TextField("Comments", text: $theTrack.comments, axis: .vertical)
                .lineLimit(3...6)
                .disabled(!canEdit)
        }

        Section("Your feedback") {
            TextField("Feedback", text: Binding(
                get: { theTrack.trackerComments ?? "" },
                set: { theTrack.trackerComments = $0 }),
                axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private func getTimeBetween(date: Date?, and toDate: Date?) -> String {
        guard let fromDate = date, let toDate = toDate else { return "-" }
        return TimeFormatter.shortTimeWithMinutesFor(seconds: fromDate.distance(to: toDate))
    }

    private func getTimeSinceCreated() -> String {
        guard let timeDistance = theTrack.created?.distance(to: Date()) else { return "-" }
        return TimeFormatter.shortTimeWithMinutesFor(seconds: timeDistance)
    }
}

struct EditTrackView_Previews: PreviewProvider {
    static let localizations = Bundle.main.localizations.map(Locale.init).filter {
        $0.identifier != "base"
    }
    static var previews: some View {
        let track = createTestTrack()
        return ForEach(ColorScheme.allCases, id: \.self) { scheme in
            ForEach(localizations, id: \.identifier) { locale in
                NavigationView {
                    EditTrackView(track)
                        .previewDevice(PreviewDevice(rawValue: "iPhone 13"))
                        .previewDisplayName("iPhone 13 \(scheme) \(locale.identifier) ")
                        .preferredColorScheme(scheme)
                        .environment(\.locale, .init(identifier: locale.identifier))
                }
            }
        }
    }

    static private func createTestTrack() -> Track {
        let track = Track(context: PersistenceController.shared.persistentContainer.viewContext)
        track.name = "Test-Track"
        track.created = Date()
        track.timeToFinish = 19 * 60
        track.difficulty = 3
        track.comments = "A little hard..."
        track.timeToCreate = 21 * 60
        track.started = Date().addingTimeInterval(60 * 60 * 3)
        track.length = 1000
        track.trackPath = [
            CLLocation(
                latitude: 52.520008,
                longitude: 13.404954
            ),
            CLLocation(
                latitude: 53.520008,
                longitude: 13.404954
            )
        ]
        track.laidPath = [
            CLLocation(
                latitude: 52.520008,
                longitude: 13.404960
            ),
            CLLocation(
                latitude: 53.520008,
                longitude: 13.507954
            )
        ]

        return track
    }
}
