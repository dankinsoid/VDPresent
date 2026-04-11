import Foundation

final class Weak<T: NSObject>: Hashable {

	let id: UUID
	private(set) weak var value: T?
	var hashValue: Int { id.hashValue }

	init(_ value: T) {
		self.value = value
		id = value.vdStableID
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}

	static func == (lhs: Weak<T>, rhs: Weak<T>) -> Bool {
		lhs.id == rhs.id
	}
}
