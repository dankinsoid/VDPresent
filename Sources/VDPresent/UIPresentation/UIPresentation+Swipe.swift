import SwiftUI

public extension UIPresentation.Interactivity {

	static var swipe: UIPresentation.Interactivity {
		swipe(to: .bottom)
	}

	static func swipe(
		to edges: NSDirectionalRectEdge,
        configuration: SwipeConfiguration = .default
	) -> UIPresentation.Interactivity {
		UIPresentation.Interactivity { context, observer in
            context.toViewControllers.forEach { controller in
                let view = context.container(for: controller)
                let tapRec = view.gestureRecognizers?.compactMap { $0 as? TransitionContainerTapRecognizer }.first
                let swipeRec = view.gestureRecognizers?.compactMap { $0 as? SwipeGestureRecognizer }.first
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
                swipeRecognizer.startFromEdges = configuration.startFromEdge
                swipeRecognizer.shouldStart = { [weak controller] edge in
                    guard let controller else { return false }
                    return configuration.shouldStart(for: context, from: controller, to: edge)
                }
                swipeRecognizer.update = { [weak controller] percent, edge in
                    guard let controller else { return }
                    observer(configuration.context(for: context, from: controller, to: edge), percent)
                }
                swipeRecognizer.target = context.view(for: controller)
                if swipeRec == nil {
                    view.addGestureRecognizer(swipeRecognizer)
                }
            }
        } uninstaller: { context in
            context.viewControllersToRemove.forEach { controller in
                let view = context.container(for: controller)
                view.gestureRecognizers?
                    .compactMap { $0 as? TransitionContainerTapRecognizer }
                    .forEach(view.removeGestureRecognizer)
                view.gestureRecognizers?
                    .compactMap { $0 as? SwipeGestureRecognizer }
                    .forEach(view.removeGestureRecognizer)
            }
        }
	}
    
    struct SwipeConfiguration {
        
        private let _shouldStart: (UIPresentation.Context, UIViewController, Edge) -> Bool
        private let _moveToEdgeContext: (UIPresentation.Context, UIViewController, Edge) -> UIPresentation.Context
        public let startFromEdge: Bool
        
        public init(
            startFromEdge: Bool = false,
            shouldStart: @escaping (UIPresentation.Context, UIViewController, Edge) -> Bool,
            moveToEdgeContext: @escaping (UIPresentation.Context, UIViewController, Edge) -> UIPresentation.Context
        ) {
            self.startFromEdge = startFromEdge
            self._shouldStart = shouldStart
            self._moveToEdgeContext = moveToEdgeContext
        }
        
        public func shouldStart(
            for context: UIPresentation.Context,
            from controller: UIViewController,
            to edge: Edge
        ) -> Bool {
            _shouldStart(context, controller, edge)
        }
        
        public func context(
            for context: UIPresentation.Context,
            from controller: UIViewController,
            to edge: Edge
        ) -> UIPresentation.Context {
            _moveToEdgeContext(context, controller, edge)
        }
        
        public static var `default`: SwipeConfiguration {
            .default(startFromEdge: false)
        }
        
        public static func `default`(startFromEdge: Bool) -> SwipeConfiguration {
            SwipeConfiguration(startFromEdge: startFromEdge) { context, controller, edge in
                guard let i = context.toViewControllers.firstIndex(of: controller) else {
                    return false
                }
                return i > 0
            } moveToEdgeContext: { context, controller, edge in
                UIPresentation.Context(
                    direction: .removal,
                    container: context.container,
                    fromViewControllers: context.toViewControllers,
                    toViewControllers: Array(
                        context.toViewControllers.prefix(
                            upTo: context.toViewControllers.firstIndex(of: controller) ?? context.toViewControllers.count - 1
                        )
                    ),
                    views: context.view,
                    animated: true,
                    isInteractive: true,
                    cache: context.cache
                )
            }
        }
    }
}
