import UIKit

final class TransitionContainerTapRecognizer: UITapGestureRecognizer, UIGestureRecognizerDelegate {
    
    var onTap: () -> Void = {}
    
    init() {
        super.init(target: nil, action: nil)
        delegate = self
        addTarget(self, action: #selector(handle))
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        gestureRecognizer.view === touch.view
    }
    
    @objc
    private func handle(_ gestureRecognizer: UIGestureRecognizer) {
        if gestureRecognizer.state == .recognized {
            onTap()
        }
    }
}
