import Foundation

private var vdStableIDKey: UInt8 = 0

extension NSObject {

	/// A process-unique, lifetime-stable identifier for this object.
	///
	/// Unlike `ObjectIdentifier`, which wraps the object's current memory
	/// address, `vdStableID` is minted lazily on first access and lives on
	/// the object itself via an associated object, so:
	///
	/// - It remains valid for the entire lifetime of the instance.
	/// - It becomes invalid together with the instance, so a freshly
	///   allocated object that happens to reuse the same memory slot gets a
	///   **different** `vdStableID` — preventing false cache hits that
	///   pointer-based identity would produce after dealloc/realloc.
	///
	/// Use this as the key whenever caching per-object state that outlives
	/// a single call — e.g. view wrappers, containers, or transition state
	/// keyed by view controller or view.
	var vdStableID: UUID {
		if let existing = objc_getAssociatedObject(self, &vdStableIDKey) as? UUID {
			return existing
		}
		let new = UUID()
		objc_setAssociatedObject(self, &vdStableIDKey, new, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
		return new
	}
}
