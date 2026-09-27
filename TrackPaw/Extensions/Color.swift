//
//  ColorPaletteExt.swift
//  TrackPaw
//
//  Created by Carl-Johan Svedin on 2022-09-14.
//

import Foundation
import SwiftUI

extension Color {
    struct Palette: Equatable {
        let name: String

        var mainBackground: Color {
            Color(fromPalette: self.name, semanticName: "background-main")
        }

        var midBackground: Color {
            Color(fromPalette: self.name, semanticName: "background-mid")
        }

        var alternativeBackground: Color {
            Color(fromPalette: self.name, semanticName: "background-alt")
        }

        var primaryText: Color {
            Color(fromPalette: self.name, semanticName: "text-primary")
        }

        var alternativeText: Color {
            Color(fromPalette: self.name, semanticName: "text-alt")
        }

        var primary: Color {
            Color(fromPalette: self.name, semanticName: "primary")
        }

        var secondary: Color {
            Color(fromPalette: self.name, semanticName: "secondary")
        }

        var tertiary: Color {
            Color(fromPalette: self.name, semanticName: "tertiary")
        }

        var quaternary: Color {
            Color(fromPalette: self.name, semanticName: "quaternary")
        }

        var link: Color {
            Color(fromPalette: self.name, semanticName: "link")
        }

        var accent: Color {
            Color(fromPalette: self.name, semanticName: "accent")
        }

        var warning: Color {
            .red
        }

        var confirm: Color {
            .green
        }
    }
}

extension Color.Palette {
    static let trackPaw = Color.Palette(name: "TrackPaw")
}

private extension Color {
    init(fromPalette palette: String, semanticName: String) {
        self.init(UIColor(named: "\(palette)/\(semanticName)")!)
    }
}

private struct ColorPaletteKey: EnvironmentKey {
    static let defaultValue = Color.Palette.trackPaw
}

extension EnvironmentValues {
    var preferredColorPalette: Color.Palette {
        get {
            return self[ColorPaletteKey.self]
        }
        set {
            self[ColorPaletteKey.self] = newValue
        }
    }
}
