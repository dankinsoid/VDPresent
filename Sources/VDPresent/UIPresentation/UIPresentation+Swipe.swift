import UIKit

public extension UIPresentation.Interactivity {

	static var swipe: UIPresentation.Interactivity {
		swipe(to: .bottom)
	}

	static func swipe(
		to edges: NSDirectionalRectEdge,
		startFromEdge: Bool = false
	) -> UIPresentation.Interactivity {
		UIPresentation.Interactivity { context, observer in
            context.toViewControllers.forEach { controller in
                let view = context.container(for: controller)
                let tapRec = view.gestureRecognizers?.compactMap { $0 as? TransitionContainerTapRecognizer }.first
                let swipeRec = view.gestureRecognizers?.compactMap { $0 as? SwipeGestureRecognizer }.first
                guard let i = context.toViewControllers.firstIndex(of: controller), i > 0 else {
                    tapRec?.isEnabled = false
                    swipeRec?.isEnabled = false
                    return
                }
                let context = UIPresentation.Context(
                    direction: .removal,
                    container: context.container,
                    fromViewControllers: context.toViewControllers,
                    toViewControllers: Array(context.toViewControllers.prefix(upTo: i)),
                    views: context.view,
                    animated: true,
                    isInteractive: true,
                    cache: context.cache
                )
                let tapRecognizer = tapRec ?? TransitionContainerTapRecognizer()
                if tapRec == nil {
                    view.addGestureRecognizer(tapRecognizer)
                }
                tapRecognizer.isEnabled = true
                tapRecognizer.onTap = { [weak controller] in
                    controller?.hide()
                }
                
                let swipeRecognizer = swipeRec ?? SwipeGestureRecognizer()
                swipeRecognizer.isEnabled = true
                swipeRecognizer.edges = edges
                swipeRecognizer.startFromEdges = startFromEdge
                swipeRecognizer.update = { percent, edge in
                    observer(context, percent)
                }
                swipeRecognizer.target = context.view(for: controller)
                if swipeRec == nil {
                    view.addGestureRecognizer(swipeRecognizer)
                }
            }
		}
	}
}
