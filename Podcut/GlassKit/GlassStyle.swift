import SwiftUI

/// Unified style contract for glass surfaces in the app.
struct GlassStyle {
    static let shared = GlassStyle()

    var strokeOpacity: Double = 0.22
    var highlightOpacity: Double = 0.16
    var shadowOpacity: Double = 0.10
    var shadowRadius: CGFloat = 16
    var shadowY: CGFloat = 10
    
    // Derived properties for convenience if needed.
    var strokeColor: Color { .white.opacity(strokeOpacity) }
    var shadowColor: Color { .black.opacity(shadowOpacity) }
}
