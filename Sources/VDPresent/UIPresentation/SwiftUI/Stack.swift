import SwiftUI
import VDTransition

public struct Stack<Content: View>: View {
    
    public let content: Content
    
    public var body: some View {
        _VariadicView.Tree(StackViewRoot()) {
            content
        }
    }
}

private struct StackViewRoot: _VariadicView.UnaryViewRoot {
    
    @ViewBuilder
    func body(children: _VariadicView.Children) -> some View {
        ZStack {
            ForEach(children) { child in
                child
            }
        }
    }
}

struct StackContext {
    
    let view: View
    let views: Views
    let direction: TransitionDirection
    
    struct Views {
        
        let from: [StackContext.View]
        let to: [StackContext.View]
    }
    
    struct View: Identifiable {
        
        let id: AnyHashable
    }
}

struct PageSheet: ViewModifier, Animatable {
    
    var animatableData: Double
    let edge: Edge
    
    func body(content: Content) -> some View {
        content
    }
}
