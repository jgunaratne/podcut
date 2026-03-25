import UIKit

extension UIColor {
    /// Returns a CSS-compatible `rgb()` string for the current trait collection.
    /// Resolves dynamic colors (like `.label`) to their concrete RGB values.
    var cssString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        // Resolve in the current trait collection.
        let resolved = self.resolvedColor(with: UITraitCollection.current)
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)

        return "rgb(\(Int(r * 255)), \(Int(g * 255)), \(Int(b * 255)))"
    }
}
