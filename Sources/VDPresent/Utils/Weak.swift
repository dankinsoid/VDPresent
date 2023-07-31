import Foundation

final class Weak<T: AnyObject & Hashable>: Hashable {
    
    let id: ObjectIdentifier
    private(set) weak var value: T?
    var hashValue: Int { id.hashValue }
    
    init(_ value: T) {
        self.value = value
        self.id = ObjectIdentifier(value)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Weak<T>, rhs: Weak<T>) -> Bool {
        lhs.id == rhs.id
    }
}
