import SwiftUI

struct TrackStatsView: View {
    @Bindable var mapModel: TrackMapModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(TimeFormatter.shortTimeWithSecondsFor(seconds: mapModel.timer.secondsElapsed))
            Text(DistanceFormatter.distanceFor(meters: mapModel.distance))
        }
        .font(.headline.monospacedDigit())
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct TrackStatsView_Previews: PreviewProvider {
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
        m1.timer.secondsElapsed = 200
        let m2 = TrackMapModel(track: track)
        m2.accuracy = 20
        m2.timer.secondsElapsed = 20

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
        m3.timer.secondsElapsed = 20

        let examples = [m1, m2, m3]

        return ForEach(examples, id: \.self) { model in
            VStack {
                Spacer()
                TrackStatsView(mapModel: model)
            }
        }
    }
}
