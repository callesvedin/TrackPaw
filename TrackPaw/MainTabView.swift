//
//  MainTabView.swift
//  TrackPaw
//
//  Created by carl-johan.svedin on 2021-03-26.
//
import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var coordinator: ViewCoordinator

    @Environment(\.preferredColorPalette) private var palette
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
        NavigationStack(path: $coordinator.path) {
            TrackListView()
        }
        .foregroundColor(palette.primaryText)
        .id(palette.name)
        .tint(palette.link)
        .preferredColorScheme(selectedScheme)
    }
}
