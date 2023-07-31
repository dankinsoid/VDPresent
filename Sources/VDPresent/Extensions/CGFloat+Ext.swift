import CoreGraphics

extension CGFloat {
    
    var notZero: CGFloat { self == 0 ? 0.0001 : self }
}
