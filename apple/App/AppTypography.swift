import SwiftUI

/// Built-in Avenir Next needs no download or bundled font. Every text style
/// follows Dynamic Type, including the title and Settings explanations.
enum AppTypography {
    #if os(tvOS)
    static let title = Font.custom("AvenirNext-UltraLight", size: 76, relativeTo: .largeTitle)
    static let subtitle = Font.custom("AvenirNext-Regular", size: 30, relativeTo: .title3)
    static let band = Font.custom("AvenirNext-UltraLight", size: 36, relativeTo: .title2)
    static let body = Font.custom("AvenirNext-Regular", size: 29, relativeTo: .body)
    static let heading = Font.custom("AvenirNext-DemiBold", size: 29, relativeTo: .headline)
    static let footnote = Font.custom("AvenirNext-Regular", size: 24, relativeTo: .footnote)
    #else
    static let title = Font.custom("AvenirNext-UltraLight", size: 44, relativeTo: .largeTitle)
    static let subtitle = Font.custom("AvenirNext-Regular", size: 20, relativeTo: .title3)
    static let band = Font.custom("AvenirNext-UltraLight", size: 28, relativeTo: .title2)
    static let body = Font.custom("AvenirNext-Regular", size: 17, relativeTo: .body)
    static let heading = Font.custom("AvenirNext-DemiBold", size: 17, relativeTo: .headline)
    static let footnote = Font.custom("AvenirNext-Regular", size: 13, relativeTo: .footnote)
    #endif
}
