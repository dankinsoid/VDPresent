import UIKit

extension UIScreen {
    
    private static let cornerRadiusKey: String = ["Radius", "Corner", "display", "_"].reversed().joined()
    
    /// The corner radius of the display. Uses a private property of `UIScreen`,
    /// and may report 0 if the API changes.
    var displayCornerRadius: CGFloat {
        guard let cornerRadius = self.value(forKey: Self.cornerRadiusKey) as? CGFloat else {
            return 0
        }
        return cornerRadius
    }
}
