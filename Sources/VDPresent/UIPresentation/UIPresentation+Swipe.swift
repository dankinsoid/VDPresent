import UIKit

public extension UIPresentation.Interactivity {
    
    static var swipe: UIPresentation.Interactivity {
        swipe(to: .bottom)
    }
    
    static func swipe(
        to edge: NSDirectionalRectEdge,
        startFromEdge: Bool = false
    ) -> UIPresentation.Interactivity {
        UIPresentation.Interactivity { context, observer in
            let swipeView: SwipeView
            let key = SwipeView.Key(edge: edge, startFromEdges: startFromEdge)
            if let existedScroll = context.container.subviews.compactMap({ $0 as? SwipeView }).first {
                swipeView = existedScroll
                context.container.bringSubviewToFront(existedScroll)
            } else {
                swipeView = SwipeView()
                context.container.addSubview(swipeView)
                swipeView.frame = context.container.bounds
                swipeView.pinEdges(to: context.container)
            }
            swipeView[key].delegate = SwipeViewObserver(observer: observer)
            swipeView.visibleContent = context.toViewControllers.last?.view
            swipeView.setNeedsLayout()
        }
    }
}

private final class SwipeViewObserver: SwipeViewDelegate {
    
    let observer: (UIPresentation.State) -> Void
    var wasBegun = false
    
    init(observer: @escaping (UIPresentation.State) -> Void) {
        self.observer = observer
    }
    
    func begin() {
        guard !wasBegun else { return }
        wasBegun = true
        observer(.begin)
    }
    
    func shouldBegin() -> Bool {
        !wasBegun
    }
    
    func update(_ percent: CGFloat) {
        observer(.change(.removal(percent)))
    }
    
    func cancel() {
        wasBegun = false
        observer(.end(completed: false))
    }
    
    func finish() {
        wasBegun = false
        observer(.end(completed: true))
    }
}
