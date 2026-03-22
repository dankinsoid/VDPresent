import UIKit

// @ai-generated(solo)
// Sandbox to test safe area propagation with shouldAutomaticallyForwardAppearanceMethods = false

/// Parent that blocks automatic appearance forwarding — mirrors UIStackController behavior.
final class SafeAreaSandboxParent: UIViewController {

	override var shouldAutomaticallyForwardAppearanceMethods: Bool { false }

	private let child = SafeAreaSandboxChild()

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = .systemGray6

		// Nested: parent.view → wrapper → child.view (like UIStackController)
		let wrapper = UIView()
		wrapper.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(wrapper)
		NSLayoutConstraint.activate([
			wrapper.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			wrapper.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			wrapper.topAnchor.constraint(equalTo: view.topAnchor),
			wrapper.bottomAnchor.constraint(equalTo: view.bottomAnchor),
		])

		addChild(child)
		child.view.translatesAutoresizingMaskIntoConstraints = false
		wrapper.addSubview(child.view)
		NSLayoutConstraint.activate([
			child.view.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
			child.view.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
			child.view.topAnchor.constraint(equalTo: wrapper.topAnchor),
			child.view.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
		])
		child.didMove(toParent: self)
	}
}

/// Child that displays its own safeAreaInsets and buttons to try triggering safe area propagation.
final class SafeAreaSandboxChild: UIViewController {

	private let label = UILabel()

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		print("⚠️ viewWillAppear called!")
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		print("⚠️ viewDidAppear called!")
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		print("⚠️ viewWillDisappear called!")
	}

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		print("⚠️ viewDidDisappear called!")
	}

	override func viewSafeAreaInsetsDidChange() {
		super.viewSafeAreaInsetsDidChange()
		print("📐 viewSafeAreaInsetsDidChange sa=t:\(Int(view.safeAreaInsets.top)),b:\(Int(view.safeAreaInsets.bottom))")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = .systemBackground

		label.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
		label.numberOfLines = 0
		label.textAlignment = .left

		let buttons: [(String, Selector)] = [
			("setNeedsLayout", #selector(trySetNeedsLayout)),
			("layoutIfNeeded", #selector(tryLayoutIfNeeded)),
			("layoutSubviews (parent)", #selector(tryParentLayout)),
			("setNeedsUpdateConstraints", #selector(tryUpdateConstraints)),
			("remove + re-add subview", #selector(tryReaddSubview)),
			("additionalSafeArea = parent", #selector(tryAdditionalSafeArea)),
			("beginAppear + endAppear", #selector(tryAppearanceTransition)),
			("viewSafeAreaInsetsDidChange", #selector(tryCallSafeAreaDidChange)),
			("insetsLayoutMarginsFromSafeArea toggle", #selector(tryToggleInsetsMargins)),
			("setNeedsSafeAreaUpdate (parent)", #selector(tryParentSafeAreaUpdate)),
			("dump VC ivar flags", #selector(tryDumpFlags)),
			("set flag byte0 bit1", #selector(trySetByte0)),
			("set flag byte3 bit1", #selector(trySetByte3)),
			("set both flags", #selector(trySetBothFlags)),
			("check side effects", #selector(tryCheckSideEffects)),
			("setBit → appear → check", #selector(tryBitThenAppear)),
			("clear bit (reset to 0)", #selector(tryClearBit)),
			("setBit → layout → clearBit", #selector(tryBitLayoutClear)),
		]

		let stack = UIStackView(arrangedSubviews: buttons.map { title, sel in
			let btn = UIButton(type: .system)
			btn.setTitle(title, for: .normal)
			btn.titleLabel?.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
			btn.contentHorizontalAlignment = .leading
			btn.addTarget(self, action: sel, for: .touchUpInside)
			return btn
		})
		stack.axis = .vertical
		stack.spacing = 6

		let outer = UIStackView(arrangedSubviews: [label, stack])
		outer.axis = .vertical
		outer.spacing = 20
		outer.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(outer)
		NSLayoutConstraint.activate([
			outer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
			outer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
			outer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
		])

		updateLabel()
	}

	private func updateLabel(_ action: String = "init") {
		let sa = view.safeAreaInsets
		let parentSA = parent?.view.safeAreaInsets ?? .zero
		let additional = additionalSafeAreaInsets
		let text = """
		child.view.safeAreaInsets:
		  t=\(Int(sa.top)) b=\(Int(sa.bottom)) l=\(Int(sa.left)) r=\(Int(sa.right))
		parent.view.safeAreaInsets:
		  t=\(Int(parentSA.top)) b=\(Int(parentSA.bottom)) l=\(Int(parentSA.left)) r=\(Int(parentSA.right))
		additional: t=\(Int(additional.top)) b=\(Int(additional.bottom))
		"""
		label.text = text
		print("[\(action)] child.sa=t:\(Int(sa.top)),b:\(Int(sa.bottom)) parent.sa=t:\(Int(parentSA.top)),b:\(Int(parentSA.bottom)) additional=t:\(Int(additional.top)),b:\(Int(additional.bottom))")
	}

	// MARK: - Actions

	@objc private func trySetNeedsLayout() {
		view.setNeedsLayout()
		DispatchQueue.main.async { self.updateLabel("setNeedsLayout") }
	}

	@objc private func tryLayoutIfNeeded() {
		view.layoutIfNeeded()
		updateLabel("layoutIfNeeded")
	}

	@objc private func tryParentLayout() {
		parent?.view.setNeedsLayout()
		parent?.view.layoutIfNeeded()
		DispatchQueue.main.async { self.updateLabel("parentLayout") }
	}

	@objc private func tryUpdateConstraints() {
		view.setNeedsUpdateConstraints()
		view.updateConstraintsIfNeeded()
		DispatchQueue.main.async { self.updateLabel("updateConstraints") }
	}

	@objc private func tryReaddSubview() {
		guard let sv = view.superview else { return }
		view.removeFromSuperview()
		sv.addSubview(view)
		DispatchQueue.main.async { self.updateLabel("readdSubview") }
	}

	@objc private func tryAdditionalSafeArea() {
		let parentSA = parent?.view.safeAreaInsets ?? .zero
		additionalSafeAreaInsets = parentSA
		DispatchQueue.main.async { self.updateLabel("additionalSafeArea=parent") }
	}

	@objc private func tryAppearanceTransition() {
		beginAppearanceTransition(true, animated: false)
		endAppearanceTransition()
		updateLabel("appearanceTransition (sync)")
		DispatchQueue.main.async {
			self.updateLabel("appearanceTransition (async1)")
			DispatchQueue.main.async {
				self.updateLabel("appearanceTransition (async2)")
			}
		}
	}

	@objc private func tryCallSafeAreaDidChange() {
		viewSafeAreaInsetsDidChange()
		DispatchQueue.main.async { self.updateLabel("safeAreaDidChange") }
	}

	@objc private func tryToggleInsetsMargins() {
		view.insetsLayoutMarginsFromSafeArea.toggle()
		view.setNeedsLayout()
		view.layoutIfNeeded()
		view.insetsLayoutMarginsFromSafeArea.toggle()
		DispatchQueue.main.async { self.updateLabel("toggleInsetsMargins") }
	}

	@objc private func tryDumpFlags() {
		// Read _viewControllerFlags as raw bytes — it's a C bitfield struct, KVC can't read it
		var count: UInt32 = 0
		if let ivars = class_copyIvarList(UIViewController.self, &count) {
			for i in 0..<Int(count) {
				let ivar = ivars[i]
				let name = String(cString: ivar_getName(ivar)!)
				if name == "_viewControllerFlags" {
					let offset = ivar_getOffset(ivar)
					let ptr = Unmanaged.passUnretained(self).toOpaque().advanced(by: offset)
					// Read 16 bytes (the struct is likely 8-16 bytes with many bit flags)
					let bytes = ptr.assumingMemoryBound(to: UInt8.self)
					let hex = (0..<16).map { String(format: "%02x", bytes[$0]) }.joined(separator: " ")
					print("_viewControllerFlags raw: \(hex)")
				}
			}
			free(ivars)
		}
	}

	private func flagsPointer() -> UnsafeMutablePointer<UInt8>? {
		var count: UInt32 = 0
		guard let ivars = class_copyIvarList(UIViewController.self, &count) else { return nil }
		defer { free(ivars) }
		for i in 0..<Int(count) {
			let name = String(cString: ivar_getName(ivars[i])!)
			if name == "_viewControllerFlags" {
				let offset = ivar_getOffset(ivars[i])
				return Unmanaged.passUnretained(self).toOpaque().advanced(by: offset).assumingMemoryBound(to: UInt8.self)
			}
		}
		return nil
	}

	@objc private func trySetByte0() {
		guard let ptr = flagsPointer() else { return }
		ptr[0] |= 0x02
		let hex = (0..<8).map { String(format: "%02x", ptr[$0]) }.joined(separator: " ")
		print("after byte0|=0x02: \(hex)")
		view.setNeedsLayout()
		DispatchQueue.main.async { self.updateLabel("setByte0") }
	}

	@objc private func trySetByte3() {
		guard let ptr = flagsPointer() else { return }
		ptr[3] |= 0x02
		let hex = (0..<8).map { String(format: "%02x", ptr[$0]) }.joined(separator: " ")
		print("after byte3|=0x02: \(hex)")
		view.setNeedsLayout()
		DispatchQueue.main.async { self.updateLabel("setByte3") }
	}

	@objc private func tryCheckSideEffects() {
		print("--- side effects ---")
		print("isBeingPresented: \(isBeingPresented)")
		print("isBeingDismissed: \(isBeingDismissed)")
		print("isMovingToParent: \(isMovingToParent)")
		print("isMovingFromParent: \(isMovingFromParent)")
		print("isViewLoaded: \(isViewLoaded)")
		print("view.window: \(view.window != nil)")
		print("parent: \(parent != nil)")
		print("presentingVC: \(presentingViewController != nil)")
		print("presentedVC: \(presentedViewController != nil)")
		if #available(iOS 13.0, *) {
			print("isModalInPresentation: \(isModalInPresentation)")
		}
		// Check appearance state via private selectors (return Int-like values)
		let intSelectors = [
			"_appearState",
			"_currentAppearState",
		]
		for selName in intSelectors {
			let sel = NSSelectorFromString(selName)
			if responds(to: sel) {
				// These return integer enums, read as unretained pointer (raw int)
				let result = perform(sel)
				let intVal = unsafeBitCast(result, to: Int.self)
				print("\(selName): \(intVal)")
			} else {
				print("\(selName): n/a")
			}
		}
		let boolSelectors = [
			"_isAppearing",
			"_isDisappearing",
		]
		for selName in boolSelectors {
			let sel = NSSelectorFromString(selName)
			if responds(to: sel) {
				let result = perform(sel)
				let boolVal = unsafeBitCast(result, to: Int.self) != 0
				print("\(selName): \(boolVal)")
			} else {
				print("\(selName): n/a")
			}
		}
		print("---")
	}

	@objc private func trySetBothFlags() {
		guard let ptr = flagsPointer() else { return }
		ptr[0] |= 0x02
		ptr[3] |= 0x02
		let hex = (0..<8).map { String(format: "%02x", ptr[$0]) }.joined(separator: " ")
		print("after both: \(hex)")
		view.setNeedsLayout()
		DispatchQueue.main.async { self.updateLabel("setBothFlags") }
	}

	@objc private func tryBitThenAppear() {
		// Simulate: non-top VC has bit set, then becomes top and gets real appearance
		guard let ptr = flagsPointer() else { return }
		print("=== setBit → appear → check ===")
		ptr[0] |= 0x02
		print("bit set, _appearState before appear:")
		tryDumpFlags()
		print("now calling beginAppear(true) + endAppear...")
		beginAppearanceTransition(true, animated: false)
		endAppearanceTransition()
		print("after real appearance:")
		tryDumpFlags()
		DispatchQueue.main.async {
			self.updateLabel("bitThenAppear")
			self.tryCheckSideEffects()
		}
	}

	@objc private func tryClearBit() {
		guard let ptr = flagsPointer() else { return }
		ptr[0] &= ~UInt8(0x02)
		let hex = (0..<8).map { String(format: "%02x", ptr[$0]) }.joined(separator: " ")
		print("after clear byte0 bit1: \(hex)")
		view.setNeedsLayout()
		DispatchQueue.main.async { self.updateLabel("clearBit") }
	}

	@objc private func tryBitLayoutClear() {
		// Set bit → wait for layout (safe area propagates) → clear bit
		guard let ptr = flagsPointer() else { return }
		ptr[0] |= 0x02
		print("bit set, waiting for layout...")
		view.setNeedsLayout()
		DispatchQueue.main.async {
			self.updateLabel("bitLayoutClear (after layout)")
			// Now clear the bit
			ptr[0] &= ~UInt8(0x02)
			print("bit cleared after layout")
			self.tryDumpFlags()
			DispatchQueue.main.async {
				self.updateLabel("bitLayoutClear (after clear)")
			}
		}
	}

	@objc private func tryParentSafeAreaUpdate() {
		if let parent {
			parent.additionalSafeAreaInsets.top += 0.001
			parent.additionalSafeAreaInsets.top -= 0.001
			parent.view.setNeedsLayout()
			parent.view.layoutIfNeeded()
		}
		DispatchQueue.main.async { self.updateLabel("parentSafeAreaUpdate") }
	}
}
