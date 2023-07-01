import SwiftUI

public extension UIPresentation.Interactivity {

	static var swipe: UIPresentation.Interactivity {
		swipe(to: .bottom)
	}
    
    @_disfavoredOverload
    static func swipe(
        to edge: Edge,
        configuration: SwipeConfiguration = .default
    ) -> UIPresentation.Interactivity {
        .swipe(to: NSDirectionalRectEdge(edge), configuration: configuration)
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
                swipeRecognizer.startFromEdges = context.environment.swipeFromEdge
                swipeRecognizer.fullDuration = context.animation.duration
                swipeRecognizer.shouldStart = { [weak controller] edge in
                    guard let controller else { return false }
                    return configuration.shouldStart(for: context, from: controller, to: edge)
                }
                swipeRecognizer.update = { [weak controller] percent, edge in
                    guard let controller else { return .prevent }
                    return observer(configuration.context(for: context, from: controller, to: edge), percent)
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
        
        public init(
            shouldStart: @escaping (UIPresentation.Context, UIViewController, Edge) -> Bool,
            moveToEdgeContext: @escaping (UIPresentation.Context, UIViewController, Edge) -> UIPresentation.Context
        ) {
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
            SwipeConfiguration { context, controller, edge in
                guard let i = context.toViewControllers.firstIndex(where: controller.isDescendant) else {
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
                            upTo: context.toViewControllers.firstIndex(where: controller.isDescendant)
                                ?? context.toViewControllers.count - 1
                        )
                    ),
                    views: context.view,
                    animated: true,
                    animation: context.animation,
                    isInteractive: true,
                    cache: context.cache,
                    environment: context.environment
                )
            }
        }
    }
}

public extension UIPresentation.Environment {
    
    var swipeFromEdge: Bool {
        get { self[\.swipeFromEdge] ?? false }
        set { self[\.swipeFromEdge] = newValue }
    }
}
