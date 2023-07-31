import UIKit

extension UIPresentation.Transition {
    
    public static func caAnimation(
        animation: @escaping (UIPresentation.Context) -> CAAnimation?,
        completion: @escaping (UIPresentation.Context, Bool) -> Void = { _, _ in }
    ) -> UIPresentation.Transition {
        UIPresentation.Transition { context in
            if !context.viewControllers.from.contains(context.viewController) {
                context.container
                    .addSubview(
                        context.view,
                        layout: context.environment.contentLayout
                    )
            }
        } animate: { context, update in
            guard let caAnimation = animation(context) else {
                update(.begin)
                update(.end(completed: true))
                completion(context, true)
                return
            }
            caAnimation.duration = context.animation.duration
            caAnimation.beginTime = CACurrentMediaTime() + context.animation.delay
            
            let delegate = AnimationDelegate()
            context.caAnimations[context.view] = delegate
            caAnimation.delegate = delegate
            
            let complete: (Bool) -> Void = { finished in
                if !finished {
                    caAnimation.speed = 0
                    caAnimation.timeOffset = 0
                }
                context.view.layer.removeAnimation(forKey: animationKey)
                context.caAnimations[context.view] = nil
                update(.end(completed: finished))
            }
            
            if context.animated {
                if context.isInteractive {
                    caAnimation.speed = 0
                    update(
                        .prepareInteractive { state in
                            switch state {
                            case .begin:
                                context.view.layer.add(caAnimation, forKey: animationKey)
                                update(.begin)
                            case let .change(progress):
                                caAnimation.timeOffset = caAnimation.duration * progress.value
                            case let .end(completed, duration):
                                if duration > 0 {
                                    delegate.completion = complete
                                    caAnimation.speed = Float((caAnimation.duration - caAnimation.timeOffset) / duration)
                                } else {
                                    caAnimation.timeOffset = caAnimation.duration
                                    complete(completed)
                                }
                            }
                        }
                    )
                } else {
                    delegate.completion = complete
                    context.view.layer.add(caAnimation, forKey: animationKey)
                    update(.begin)
                }
            } else {
                caAnimation.speed = 0
                context.view.layer.add(caAnimation, forKey: animationKey)
                update(.begin)
                caAnimation.timeOffset = caAnimation.duration
                completion(context, true)
            }
        } completion: { context, completed in
            completion(context, completed)
        }
    }
}

private final class AnimationDelegate: NSObject, CAAnimationDelegate {
    
    var completion: ((Bool) -> Void)?
    
    /* Called when the animation begins its active duration. */
    func animationDidStart(_ anim: CAAnimation) {
    }
    
    /* Called when the animation either completes its active duration or
     * is removed from the object it is attached to (i.e. the layer). 'flag'
     * is true if the animation reached the end of its active duration
     * without being removed. */
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        completion?(flag)
    }
}

private let animationKey = "UIPresentation.Transition.Animation"

private extension UIPresentation.Context {
 
    var caAnimations: [Weak<UIView>: AnimationDelegate] {
        get { cache[\.caAnimations] ?? [:] }
        nonmutating set { cache[\.caAnimations] = newValue }
    }
}
