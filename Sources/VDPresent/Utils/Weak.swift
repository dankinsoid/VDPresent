import Foundation

struct Weak<T: AnyObject>: Hashable {
    
    weak var value: T?
    
    init(_ value: T?) {
        self.value = value
    }
    
    func hash(into hasher: inout Hasher) {
        let id = value.map { ObjectIdentifier($0) } ?? ObjectIdentifier(Self.self)
        id.hash(into: &hasher)
    }
    
    static func == (lhs: Weak<T>, rhs: Weak<T>) -> Bool {
        lhs.value === rhs.value
    }
}
