//
//  StateButtonView.swift
//  TrackPaw
//
//  Created by Carl-Johan Svedin on 2022-08-17.
//

import SwiftUI

struct StateButtonView: View {
    @Environment(\.preferredColorPalette) private var palette

    @Bindable var mapModel: TrackMapModel

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                if !mapModel.showButtons {
                    EmptyView()
                } else if mapModel.preview {
                    Button("Close") { mapModel.stop() }
                        .buttonStyle(.glass)
                } else {
                    if mapModel.currentState == .notStarted {
                        Button("Close") { mapModel.stop() }
                            .buttonStyle(.glass)
                        if mapModel.locationAuthorizationStatus != .denied {
                            Button("Start") { mapModel.start() }
                                .buttonStyle(.glassProminent)
                                .tint(palette.confirm)
                                .disabled(mapModel.accuracy > 10)
                        }
                    }
                    if mapModel.currentState == .running {
                        Button("Pause") { mapModel.pause() }
                            .buttonStyle(.glass)
                    }
                    if mapModel.currentState == .paused {
                        Button("Continue") { mapModel.resume() }
                            .buttonStyle(.glassProminent)
                            .tint(palette.confirm)
                        Button("Stop") { mapModel.stop() }
                            .buttonStyle(.glassProminent)
                            .tint(palette.warning)
                    }
                    if mapModel.currentState == .viewing {
                        Button("Close") { mapModel.stop() }
                            .buttonStyle(.glassProminent)
                            .tint(palette.confirm)
                    }
                }
            }
            .controlSize(.large)
            .font(.headline)
        }
    }
}

struct StateButtonView_Previews: PreviewProvider {
    static var previews: some View {
        let track = Track(context: PersistenceController.shared.persistentContainer.viewContext)
        track.name = "Test-Track"
        track.created = Date()
        // track.timeToFinish = 19*60
        track.difficulty = 3
        track.comments = "A little hard..."
        track.timeToCreate = 21*60
        track.started = Date().addingTimeInterval(60*60*3)
        track.length = 1000
        let m1 = TrackMapModel(track: track)
        m1.accuracy = 4
        let m2 = TrackMapModel(track: track)
        m2.accuracy = 20

        let track2 = Track(context: PersistenceController.shared.persistentContainer.viewContext)
        track2.name = "Test-Track"
        track2.created = Date()
        track2.timeToFinish = 19*60
        track2.difficulty = 3
        track2.comments = "A little hard..."
        track2.timeToCreate = 21*60
        track2.started = Date().addingTimeInterval(60*60*3)
        track2.length = 1000
        let m3 = TrackMapModel(track: track2)
        m3.accuracy = 4

        let examples = [m1, m2, m3]

        return ForEach(examples, id: \.self) { model in
            VStack {
                Spacer()
                StateButtonView(mapModel: model)
            }
        }
    }
}
