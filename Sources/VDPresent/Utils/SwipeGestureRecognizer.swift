import SwiftUI
import VDTransition

final class SwipeGestureRecognizer: UIPanGestureRecognizer, UIGestureRecognizerDelegate {
    
    var startFromEdges = false
    var edges: NSDirectionalRectEdge = []
    var shouldStart: (Edge) -> Bool = { _ in true }
    var update: (UIPresentation.Interactivity.State, Edge) -> UIPresentation.Interactivity.Policy = { _, _ in .prevent }
    var direction: TransitionDirection = .removal
    var fullDuration: Double = UIKitAnimation.defaultDuration
    weak var target: UIView?
    private var edge: Edge?
    private var axis: NSLayoutConstraint.Axis {
        switch edge {
        case .leading, .trailing: return .horizontal
        default: return .vertical
        }
    }
    private var wasBegun = false
    private var lastPercent: CGFloat?
    private var initialPercent: CGFloat = 0
    private var displayLink: DisplayLink?
    
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
            guard !wasBegun else {
                if displayLink != nil {
                    initialPercent = lastPercent ?? 0
                    displayLink = nil
                }
                return
            }
            setAxisIfNeeded()
            if update(.begin, edge ?? .leading) == .allow {
                wasBegun = true
            } else {
                stop()
            }
            
        case .changed:
            guard wasBegun else { return }
            let percent = abs(max(0, min(1, percent)))
            update(percent: percent)
            
        case .ended:
            guard wasBegun else { return }
            finish(completed: percent > 0.35 || velocityInDirection > 800)
            
        case .failed, .cancelled:
            guard wasBegun else { return }
            finish(completed: false)
            
        @unknown default:
            break
        }
    }
    
    private func update(percent: Double) {
        guard percent != lastPercent else { return }
        lastPercent = percent
        if update(.change(direction.at(percent)), edge ?? .leading) == .prevent {
            stop()
        }
    }
    
    private func finish(completed: Bool) {
        _ = update(.end(completed: completed, after: fullDuration), edge ?? .leading)
        stop()
//        let _percent = percent
//        displayLink = DisplayLink(duration: fullDuration) { [weak self] progress in
//            guard let self else { return }
//            let percent = completed
//                ? _percent + (1 - _percent) * progress
//                : _percent * (1 - progress)
//            update(percent: percent)
//            if progress == 1 {
//                _ = update(.end(completed: completed, after: 0), edge ?? .leading)
//                stop()
//            }
//        }
//        displayLink?.start()
    }
    
    private func stop() {
        wasBegun = false
        lastPercent = nil
        edge = nil
        displayLink = nil
    }
    
    private var percent: CGFloat {
        guard let target else { return 0 }
        setAxisIfNeeded()
        switch axis {
        case .vertical:
            guard target.frame.height > 0 else { return 1 }
            return offset / target.frame.height
        case .horizontal:
            guard target.frame.width > 0 else { return 1 }
            return offset / target.frame.width
        @unknown default:
            return initialPercent
        }
    }
    
    private var offset: CGFloat {
        guard let view else { return 0 }
        var value: CGFloat
        let offset = translation(in: view)
        setAxisIfNeeded()
        switch axis {
        case .vertical:
            guard edges.contains(.top) || edges.contains(.bottom) else { return 0 }
            value = -offset.y
            if edges.contains(.bottom), edges.contains(.top) {
                value = abs(value)
            } else if edges.contains(.bottom) {
                value = -value
            }
            return value + initialPercent * (target?.frame.height ?? 0)
            
        case .horizontal:
            guard edges.contains(.leading) || edges.contains(.trailing) else { return 0 }
            value = -offset.x
            if edges.contains(.trailing), edges.contains(.leading) {
                value = abs(value)
            } else if edges.contains(.trailing) {
                value = -value
            }
            return value + initialPercent * (target?.frame.width ?? 0)
            
        @unknown default:
            return 0
        }
    }
    
    private var velocityInDirection: CGFloat {
        let vector = velocity(in: view)
        let isLtr = view?.effectiveUserInterfaceLayoutDirection != .rightToLeft
        switch edge {
        case .top:
            return -vector.y
        case .bottom:
            return vector.y
        case .trailing:
            return isLtr ? vector.x : -vector.x
        default:
            return isLtr ? -vector.x : vector.x
        }
    }
    
    private func setAxisIfNeeded() {
        guard edge == nil else { return }
        edge = computeEdge()
    }
    
    private func computeEdge() -> Edge {
        let offset = velocity(in: view)
        let isLtr = view?.effectiveUserInterfaceLayoutDirection != .rightToLeft
        let leftEdge: Edge = isLtr ? .leading : .trailing
        let rightEdge: Edge = isLtr ? .trailing : .leading
        return abs(offset.x) < abs(offset.y)
            ? offset.y < 0 ? .top : .bottom
            : offset.x < 0 ? leftEdge : rightEdge
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let edge = computeEdge()
        guard
            let view,
            let target,
            target.bounds.contains(gestureRecognizer.location(in: target)),
            edges.contains(NSDirectionalRectEdge(edge)),
            shouldStart(computeEdge())
        else {
            return false
        }
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

private final class DisplayLink: NSObject {
    
    private var displayLink: CADisplayLink?
    private var startedAt: Double?
    private let duration: Double
    private let observe: (Double) -> Void
    
    init(duration: Double, observer: @escaping (Double) -> Void) {
        self.duration = duration
        self.observe = observer
        super.init()
    }
    
    func start() {
        displayLink = CADisplayLink(target: self, selector: #selector(handler))
        displayLink?.add(to: .main, forMode: .default)
        startedAt = CACurrentMediaTime()
    }
    
    deinit {
        displayLink?.isPaused = true
        displayLink?.invalidate()
    }
    
    @objc private func handler(displayLink: CADisplayLink) {
        let currentTime = CACurrentMediaTime()
        let completed = duration > 0
            ? min(1, max(0, (currentTime - (startedAt ?? currentTime)) / duration))
            : 1.0
        if completed == 1 {
            displayLink.isPaused = true
        }
        observe(completed)
    }
}
