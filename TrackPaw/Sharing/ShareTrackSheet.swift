import SwiftUI

/// Sheet content whose root hosts the `ShareLink`, so it presents reliably.
/// Presented via `.sheet(item:)` from contexts (swipe actions, menus) that
/// cannot host a `ShareLink` directly.
///
/// Styling note: the sheet sets its own opaque background and explicit,
/// scheme-adaptive text colors rather than inheriting the presenter's
/// near-white `primaryText`, which would be unreadable on a light-mode sheet.
struct ShareTrackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.preferredColorPalette) private var palette
    let track: Track

    var body: some View {
        VStack(spacing: 20) {
            Text("Share “\(track.name)”")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Text("Invite someone to track this trail with their dog.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            ShareLink(
                item: TrackSharingService.shared.makeTransferable(for: track),
                preview: SharePreview(track.name)
            ) {
                Label("Share Track", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(palette.accent, in: Capsule())
            }
            .buttonStyle(.plain)

            Button { dismiss() } label: {
                Text("Cancel")
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
        // Adaptive system text colors (dark in light mode, light in dark mode)
        // so they contrast with `mainBackground` in both appearances.
        .foregroundStyle(.primary)
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationDetents([.medium])
        .presentationBackground(palette.mainBackground)
    }
}
