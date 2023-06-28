import UIKit
import VDTransition

final class SwipeGestureRecognizer: UIPanGestureRecognizer, UIGestureRecognizerDelegate {
    
    var startFromEdges = false
    var edges: NSDirectionalRectEdge = []
    var update: (UIPresentation.State) -> Void = { _ in }
    var direction: TransitionDirection = .removal
    weak var target: UIView?
    private var axis: NSLayoutConstraint.Axis?
    private var wasBegun = false
    private var lastPercent: CGFloat?
    
    init() {
        super.init(target: nil, action: nil)
        delegate = self
        addTarget(self, action: #selector(handle))
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let target, let view = touch.view else { return false }
        return view.isDescendant(of: target) && target.bounds.contains(touch.location(in: target))
    }
    
    @objc
    private func handle(_ gestureRecognizer: UIPanGestureRecognizer) {
        switch gestureRecognizer.state {
        case .possible:
            break
            
        case .began:
            guard !wasBegun else { return }
            wasBegun = true
            update(.begin)
            
        case .changed:
            guard wasBegun else { return }
            let percent = abs(max(0, min(1, percent)))
            guard percent != lastPercent else { return }
            lastPercent = percent
            update(.change(direction.at(percent)))
            
        case .ended:
            finish(completed: percent > 0.5)
            
        case .failed, .cancelled:
            finish(completed: false)
            
        @unknown default:
            break
        }
    }
    
    private func finish(completed: Bool) {
        wasBegun = false
        axis = nil
        lastPercent = nil
        let duration = UIKitAnimation.defaultDuration * (completed ? (1 - percent) : percent)
        update(.end(completed: completed, animation: .default(duration)))
    }
    
    private var percent: CGFloat {
        guard let target else { return 0 }
        setAxisIfNeeded()
        switch axis ?? .vertical {
        case .vertical:
            guard target.frame.height > 0 else { return 1 }
            return offset / target.frame.height
        case .horizontal:
            guard target.frame.width > 0 else { return 1 }
            return offset / target.frame.width
        @unknown default:
            return 0
        }
    }
    
    private var offset: CGFloat {
        guard let view else { return 0 }
        var value: CGFloat
        let offset = translation(in: view)
        setAxisIfNeeded()
        switch axis ?? .vertical {
        case .vertical:
            guard edges.contains(.top) || edges.contains(.bottom) else { return 0 }
            value = -offset.y
            if edges.contains(.bottom), edges.contains(.top) {
                value = abs(value)
            } else if edges.contains(.bottom) {
                value = -value
            }
            return value
            
        case .horizontal:
            guard edges.contains(.leading) || edges.contains(.trailing) else { return 0 }
            value = -offset.x
            if edges.contains(.trailing), edges.contains(.leading) {
                value = abs(value)
            } else if edges.contains(.trailing) {
                value = -value
            }
            return value
            
        @unknown default:
            return 0
        }
    }
    
    private func setAxisIfNeeded() {
        guard axis == nil else { return }
        let offset = velocity   (in: view)
        axis = abs(offset.x) < abs(offset.y) ? .vertical : .horizontal
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let view, let target, target.bounds.contains(gestureRecognizer.location(in: target)) else { return false }
        let threshold: CGFloat = 36
        guard startFromEdges else {
            return true
        }
        let size = view.frame.size
        let location = gestureRecognizer.location(in: view)
        
        let edgeInsets = view.nsDirectionalEdgeInsets(
            top: abs(location.y),
            left: abs(location.x),
            bottom: abs(size.height - location.y),
            right: abs(size.width - location.x)
        )
        
        let result = (
            edges.contains(.trailing) && edgeInsets.leading < threshold ||
            edges.contains(.leading) && edgeInsets.trailing < threshold ||
            edges.contains(.top) && edgeInsets.bottom < threshold ||
            edges.contains(.bottom) && edgeInsets.top < threshold
        )
        return result
    }
}
