import SwiftUI

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
            children
        }
    }
}
