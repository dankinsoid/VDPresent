import Foundation

extension Dictionary {
    
    subscript<T: AnyObject>(_ key: T) -> Value? where Key == Weak<T> {
        get { self[Weak(key)] }
        set { self[Weak(key)] = newValue }
    }
    
    subscript<T: AnyObject>(_ key: T, default value: Value) -> Value where Key == Weak<T> {
        get { self[Weak(key), default: value] }
        set { self[Weak(key)] = newValue }
    }
}
