import UIKit

// MARK: - NativeNavRootViewController

/// Root of a plain UIKit `UINavigationController` stack used to compare native
/// push/pop behavior with VDPresent's `.navigation` presentation.
///
/// This screen offers a single "Push" button. The pushed screen focuses a text
/// field in `viewWillAppear` and resigns it in `viewWillDisappear`, so the
/// keyboard animation runs concurrently with the native navigation transition.
/// During the push, `viewWillAppear` also taps into `transitionCoordinator` to
/// log every subview of `transitionContext.containerView` together with its
/// `backgroundColor` — this is how we inspect whether UIKit inserts any
/// dimming view and, if so, which color it uses.
/// @ai-generated(solo)
final class NativeNavRootViewController: UIViewController {

	override func viewDidLoad() {
		super.viewDidLoad()
		title = "Native Nav Root"
		view.backgroundColor = .systemBackground
		view.accessibilityIdentifier = "NativeNavRoot"

		let pushButton = UIButton(type: .system)
		pushButton.setTitle("Push →", for: .normal)
		pushButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
		pushButton.backgroundColor = .systemBlue
		pushButton.setTitleColor(.white, for: .normal)
		pushButton.layer.cornerRadius = 14
		pushButton.layer.cornerCurve = .continuous
		pushButton.addTarget(self, action: #selector(didTapPush), for: .touchUpInside)

		let infoLabel = UILabel()
		infoLabel.font = .systemFont(ofSize: 15)
		infoLabel.textColor = .secondaryLabel
		infoLabel.numberOfLines = 0
		infoLabel.text = "Tapping Push navigates to a screen whose text field becomes first responder in viewWillAppear and resigns in viewWillDisappear. During the push, the pushed screen logs transitionContext.containerView.subviews + backgroundColor to the console — that's how we inspect UIKit's native dimming view."

		let stack = UIStackView(arrangedSubviews: [infoLabel, pushButton])
		stack.axis = .vertical
		stack.spacing = 20
		stack.alignment = .fill
		stack.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(stack)

		NSLayoutConstraint.activate([
			stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
			stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
			stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
			pushButton.heightAnchor.constraint(equalToConstant: 50),
		])
	}

	@objc private func didTapPush() {
		navigationController?.pushViewController(NativeNavPushedViewController(), animated: true)
	}
}

// MARK: - NativeNavPushedViewController

/// Pushed screen used by ``NativeNavRootViewController``.
///
/// - Grabs first-responder focus on `viewWillAppear` and releases it on
///   `viewWillDisappear` so the keyboard animation overlaps the transition.
/// - On `viewWillAppear` inspects `transitionCoordinator.containerView` and
///   logs every subview together with its `backgroundColor`, capturing the
///   exact moment native UIKit push animation is running.
/// @ai-generated(solo)
final class NativeNavPushedViewController: UIViewController {

	private let textField: UITextField = {
		let tf = UITextField()
		tf.borderStyle = .roundedRect
		tf.placeholder = "Focused on viewWillAppear"
		tf.font = .systemFont(ofSize: 17)
		tf.returnKeyType = .done
		return tf
	}()

	override func viewDidLoad() {
		super.viewDidLoad()
		title = "Native Nav Pushed"
		view.backgroundColor = .systemBackground
		view.accessibilityIdentifier = "NativeNavPushed"

		let titleLabel = UILabel()
		titleLabel.font = .monospacedSystemFont(ofSize: 20, weight: .bold)
		titleLabel.text = "Native UINavigationController push"
		titleLabel.numberOfLines = 0

		let descLabel = UILabel()
		descLabel.font = .systemFont(ofSize: 15)
		descLabel.textColor = .secondaryLabel
		descLabel.numberOfLines = 0
		descLabel.text = "Check the console: on push/pop the transitionContext containerView subviews are logged together with their backgroundColor. This is how we see if UIKit adds a dimming view under the outgoing controller."

		let stack = UIStackView(arrangedSubviews: [titleLabel, descLabel, textField])
		stack.axis = .vertical
		stack.spacing = 16
		stack.setCustomSpacing(8, after: titleLabel)
		stack.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(stack)

		NSLayoutConstraint.activate([
			stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
			stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
			stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
		])
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		print("🟢 [NativeNavPushed] viewWillAppear → becomeFirstResponder")
		textField.becomeFirstResponder()
		logContainerSubviews(phase: "willAppear")
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		logContainerSubviews(phase: "didAppear")
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		print("🔴 [NativeNavPushed] viewWillDisappear → resignFirstResponder")
		textField.resignFirstResponder()
		logContainerSubviews(phase: "willDisappear")
	}

	// MARK: - Private

	/// Walks the current transition's `containerView` and prints every subview
	/// plus its `backgroundColor`. Runs both synchronously (to see the state at
	/// the start of the transition) and inside `animate(alongsideTransition:)`
	/// (to see it mid-animation, when UIKit has already installed any dimming
	/// layer under the outgoing VC).
	private func logContainerSubviews(phase: String) {
		guard let coordinator = transitionCoordinator else {
			print("⚠️ [NativeNavPushed] \(phase): no transitionCoordinator")
			return
		}

		let container = coordinator.containerView
		print("── [NativeNavPushed] \(phase) SYNC containerView=\(type(of: container)) frame=\(container.frame)")
		dumpSubviews(of: container, indent: "  ")

		coordinator.animate(alongsideTransition: { context in
			let box = context.containerView
			print("── [NativeNavPushed] \(phase) DURING containerView=\(type(of: box)) frame=\(box.frame)")
			Self.dumpSubviewsStatic(of: box, indent: "  ")
		}, completion: { context in
			let box = context.containerView
			print("── [NativeNavPushed] \(phase) AFTER containerView=\(type(of: box)) frame=\(box.frame)")
			Self.dumpSubviewsStatic(of: box, indent: "  ")
		})
	}

	private func dumpSubviews(of view: UIView, indent: String) {
		Self.dumpSubviewsStatic(of: view, indent: indent)
	}

	private static func dumpSubviewsStatic(of view: UIView, indent: String) {
		for sub in view.subviews {
			let bg = sub.backgroundColor.map { "\($0)" } ?? "nil"
			let alpha = sub.alpha
			let hidden = sub.isHidden
			print("\(indent)• \(type(of: sub)) bg=\(bg) alpha=\(alpha) hidden=\(hidden) frame=\(sub.frame)")
		}
	}
}
