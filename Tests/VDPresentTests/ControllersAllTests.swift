import XCTest
@testable import VDPresent
import UIKit

// @ai-generated(solo)
final class ControllersAllTests: XCTestCase {

	// MARK: - Helpers

	/// Creates identifiable view controllers for readable assertions.
	private func vcs(_ count: Int) -> [UIViewController] {
		(0..<count).map {
			let vc = UIViewController()
			vc.view.accessibilityIdentifier = "\($0)"
			return vc
		}
	}

	/// Extracts accessibility identifiers for readable test output.
	private func ids(_ controllers: [UIViewController]) -> [String] {
		controllers.map { $0.view.accessibilityIdentifier ?? "?" }
	}

	private func controllers(
		from: [UIViewController],
		to: [UIViewController]
	) -> UIPresentation.Context.Controllers {
		UIPresentation.Context.Controllers(
			fromViewControllers: from,
			toViewControllers: to
		)
	}

	// MARK: - Edge cases

	func testEmptyFrom_returnsTo() {
		let abc = vcs(3)
		let c = controllers(from: [], to: abc)
		XCTAssertEqual(ids(c.all(.insertion)), ids(abc))
	}

	func testEmptyTo_returnsFrom() {
		let abc = vcs(3)
		let c = controllers(from: abc, to: [])
		XCTAssertEqual(ids(c.all(.removal)), ids(abc))
	}

	// MARK: - Push (insertion)

	/// Simple push: [A, B] → [A, B, C]
	/// Expected: [A, B, C] — B (old top) behind C (new top).
	func testSimplePush() {
		let all = vcs(3)
		let (a, b, c) = (all[0], all[1], all[2])
		let ctrl = controllers(from: [a, b], to: [a, b, c])
		let result = ctrl.all(.insertion)
		XCTAssertEqual(ids(result), ["0", "1", "2"])
		// New top is last
		XCTAssert(result.last === c)
		// Old top is second to last
		XCTAssert(result[result.count - 2] === b)
	}

	// MARK: - Pop (removal)

	/// Simple pop: [A, B] → [A]
	/// Expected: [A, B] — B (old top) in front during exit animation.
	func testSimplePop() {
		let all = vcs(2)
		let (a, b) = (all[0], all[1])
		let ctrl = controllers(from: [a, b], to: [a])
		let result = ctrl.all(.removal)
		XCTAssertEqual(ids(result), ["0", "1"])
		// Old top is last (animates out on top)
		XCTAssert(result.last === b)
	}

	/// Pop to root: [A, B, C, D] → [A]
	/// Expected: [A, B, C, D] — departing controllers keep their from order,
	/// D (old top) is last.
	func testPopToRoot() {
		let all = vcs(4)
		let (a, b, c, d) = (all[0], all[1], all[2], all[3])
		let ctrl = controllers(from: [a, b, c, d], to: [a])
		let result = ctrl.all(.removal)
		XCTAssertEqual(ids(result), ["0", "1", "2", "3"])
		XCTAssert(result.last === d)
	}

	// MARK: - Same top

	/// No change: [A, B] → [A, B]
	/// Expected: [A, B] — order preserved.
	func testNoChange() {
		let all = vcs(2)
		let ctrl = controllers(from: all, to: all)
		XCTAssertEqual(ids(ctrl.all(.insertion)), ["0", "1"])
	}

	// MARK: - Reorder

	/// Reorder with removals: [1, 2, 3, 4, 5] → [1, 4, 2]
	/// 3 and 5 are removed. 3 should be inserted before 4 (its right neighbour).
	/// 5 has no right neighbour → goes to end, then tops rearranged.
	func testReorderWithRemovals() {
		let all = vcs(5)
		let ctrl = controllers(
			from: [all[0], all[1], all[2], all[3], all[4]],
			to: [all[0], all[3], all[1]]
		)
		let result = ctrl.all(.removal)
		// all[1] is new top (to.last) — remaining, stays in place
		// all[4] is old top (from.last) — changing, pulled to end
		// all[2] inserted before its right neighbour (all[3])
		XCTAssertEqual(ids(result), ["0", "2", "3", "1", "4"])
		XCTAssert(result.last === all[4])
		XCTAssertEqual(result.count, 5)
	}

	// MARK: - Insert in middle

	/// Insert into middle: [A, C] → [A, B, C]
	/// Top is same (C), so no top rearrangement needed.
	func testInsertMiddle() {
		let all = vcs(3)
		let (a, b, c) = (all[0], all[1], all[2])
		let ctrl = controllers(from: [a, c], to: [a, b, c])
		let result = ctrl.all(.insertion)
		XCTAssertEqual(ids(result), ["0", "1", "2"])
	}

	// MARK: - Common prefix optimisation

	/// Push with deep common prefix: [A, B, C, D] → [A, B, C, D, E]
	/// All of from is a prefix of to.
	func testDeepCommonPrefix() {
		let all = vcs(5)
		let ctrl = controllers(
			from: Array(all[0...3]),
			to: all
		)
		let result = ctrl.all(.insertion)
		XCTAssertEqual(ids(result), ["0", "1", "2", "3", "4"])
		XCTAssert(result.last === all[4])
	}

	// MARK: - Single element stacks

	func testSingleToSingle_differentControllers() {
		let all = vcs(2)
		let ctrl = controllers(from: [all[0]], to: [all[1]])
		let resultInsertion = ctrl.all(.insertion)
		// New top last during insertion
		XCTAssert(resultInsertion.last === all[1])
		XCTAssertEqual(resultInsertion.count, 2)

		let resultRemoval = ctrl.all(.removal)
		// Old top last during removal
		XCTAssert(resultRemoval.last === all[0])
		XCTAssertEqual(resultRemoval.count, 2)
	}

	// MARK: - Departing controller placed near neighbour

	/// [A, B, C, D] → [A, D]  (B and C removed)
	/// B's right neighbour in from is C (also removed), then D (in merged) → B before D.
	/// C's right neighbour in from is D (in merged) → C before D.
	/// Result should be: [A, B, C, D] or with top handling.
	func testMultipleRemovalsPreserveOrder() {
		let all = vcs(4)
		let (a, b, c, d) = (all[0], all[1], all[2], all[3])
		let ctrl = controllers(from: [a, b, c, d], to: [a, d])
		let result = ctrl.all(.removal)
		// D is both old and new top → tops are same, no rearrangement
		// B and C should be between A and D
		XCTAssertEqual(ids(result), ["0", "1", "2", "3"])
	}
}
