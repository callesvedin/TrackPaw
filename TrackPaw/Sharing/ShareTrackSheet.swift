import SwiftUI

/// Sheet content whose root hosts the `ShareLink`, so it presents reliably.
/// Presented via `.sheet(item:)` from contexts (swipe actions, menus) that
/// cannot host a `ShareLink` directly.
struct ShareTrackSheet: View {
    @Environment(\.dismiss) private var dismiss
    let track: Track

    var body: some View {
        VStack(spacing: 24) {
            Text("Share “\(track.name)”")
                .font(.headline)
            Text("Invite someone to track this trail with their dog.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            ShareLink(
                item: TrackSharingService.shared.makeTransferable(for: track),
                preview: SharePreview(track.name)
            ) {
                Label("Share Track", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            Button("Cancel") { dismiss() }
        }
        .padding()
        .presentationDetents([.medium])
    }
}
