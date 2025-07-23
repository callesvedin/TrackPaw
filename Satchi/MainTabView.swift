//
//  MainTabView.swift
//  Satchi
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
        setNavigationColors(background: palette.mainBackground, text: palette.primaryText)

        return NavigationStack(path: $coordinator.path) {
            TrackListView()
        }
        .foregroundColor(palette.primaryText)        
        .id(palette.name)
        .accentColor(palette.link)
        .preferredColorScheme(selectedScheme)
    }
}

private func setNavigationColors(background: Color, text: Color) {
    let backgroundColor = UIColor(background)

    let textColor = UIColor(text)
    let coloredAppearance = UINavigationBarAppearance()
    coloredAppearance.configureWithTransparentBackground()
    coloredAppearance.backgroundColor = backgroundColor
    coloredAppearance.titleTextAttributes = [.foregroundColor: textColor]
    coloredAppearance.largeTitleTextAttributes = [.foregroundColor: textColor]
    if #available(iOS 15.0, *) {
        UINavigationBar.appearance().compactScrollEdgeAppearance = coloredAppearance
    }
    UINavigationBar.appearance().standardAppearance = coloredAppearance
    UINavigationBar.appearance().compactAppearance = coloredAppearance
    UINavigationBar.appearance().scrollEdgeAppearance = coloredAppearance
    UINavigationBar.appearance().tintColor = textColor
}

//
// struct MainTabView_Previews: PreviewProvider {
//    static var previews: some View {
//        MainTabView()
//            .environmentObject(CoreDataStack.preview)
//            .environment(\.managedObjectContext, CoreDataStack.preview.context)
//
//    }
// }
