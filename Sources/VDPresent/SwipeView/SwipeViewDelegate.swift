import UIKit

protocol SwipeViewDelegate: AnyObject {

    var wasBegun: Bool { get }
    func begin()
    func shouldBegin() -> Bool
    func update(_ percent: CGFloat)
    func cancel()
    func finish()
}
