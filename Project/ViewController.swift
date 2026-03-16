import UIKit
import VDPresent

// MARK: - DemoItem

struct DemoItem {
	let title: String
	let description: String
	let code: String
	/// Custom row tap handler. When nil the row shows DemoViewController as `presentation`.
	let tapAction: ((UIViewController) -> Void)?
	let presentation: UIPresentation

	init(
		title: String,
		description: String,
		code: String,
		presentation: UIPresentation,
		tapAction: ((UIViewController) -> Void)? = nil
	) {
		self.title = title
		self.description = description
		self.code = code
		self.presentation = presentation
		self.tapAction = tapAction
	}
}

// MARK: - TableHeaderView

/// A UIView subclass for use as tableHeaderView that avoids AutoLayout constraint conflicts.
/// UIKit assigns tableHeaderView width=0 on the first layout pass, which breaks any
/// UIStackView with isLayoutMarginsRelativeArrangement. This view overrides its frame
/// to always span the full table width so child AutoLayout constraints resolve correctly.
/// @ai-generated(solo)
private final class TableHeaderView: UIView {

	private let fixedHeight: CGFloat

	init(height: CGFloat) {
		fixedHeight = height
		super.init(frame: CGRect(x: 0, y: 0, width: 320, height: height))
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) { fatalError() }

	override var intrinsicContentSize: CGSize {
		CGSize(width: UIView.noIntrinsicMetric, height: fixedHeight)
	}
}

// MARK: - MainMenuViewController

/// @ai-generated(solo)
final class MainMenuViewController: UITableViewController {

	struct DemoSection {
		let title: String
		let items: [DemoItem]
	}

	private let sections: [DemoSection] = [
		.init(title: "Presentations", items: [
			.init(
				title: ".sheet",
				description: "Slides in from the bottom with rounded corners. Swipe down to dismiss.",
				code: "controller.show(as: .sheet)",
				presentation: .sheet
			),
			.init(
				title: ".pageSheet",
				description: "Scales and dims the previous screen as the sheet slides in.",
				code: "controller.show(as: .pageSheet)",
				presentation: .pageSheet
			),
			.init(
				title: ".push",
				description: "Previous screen slides back at 30% offset. Swipe from the right edge to go back.",
				code: "controller.show(as: .push)",
				presentation: .push
			),
			.init(
				title: ".fullScreen",
				description: "Covers the entire screen. No interactive gesture by default.",
				code: "controller.show(as: .fullScreen)",
				presentation: .fullScreen
			),
		]),
		.init(title: "Edges", items: [
			.init(
				title: ".sheet(from: .top)",
				description: "Same sheet mechanics, but slides in from the top.",
				code: "controller.show(as: .sheet(from: .top))",
				presentation: .sheet(from: .top)
			),
			.init(
				title: ".sheet(from: .leading)",
				description: "Sheet from the left edge (right edge in RTL).",
				code: "controller.show(as: .sheet(from: .leading))",
				presentation: .sheet(from: .leading)
			),
			.init(
				title: ".sheet(from: .trailing)",
				description: "Sheet from the right edge (left edge in RTL).",
				code: "controller.show(as: .sheet(from: .trailing))",
				presentation: .sheet(from: .trailing)
			),
			.init(
				title: ".push(from: .leading)",
				description: "Push from the left — mirrors a back-navigation gesture.",
				code: "controller.show(as: .push(from: .leading))",
				presentation: .push(from: .leading)
			),
		]),
		.init(title: "Interactivity", items: [
			.init(
				title: ".nonInteractive",
				description: "Sheet without the swipe gesture. Only the Dismiss button closes it.",
				code: "controller.show(as: .sheet.nonInteractive)",
				presentation: .sheet.nonInteractive
			),
			.init(
				title: ".fullScreen(interactive: true)",
				description: "Full-screen presentation with swipe-to-dismiss enabled.",
				code: "controller.show(as: .fullScreen(from: .bottom, interactive: true))",
				presentation: .fullScreen(from: .bottom, interactive: true)
			),
		]),
		.init(title: "Stack", items: stackSectionItems()),
	]

	init() {
		super.init(style: .insetGrouped)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) { fatalError() }

	override func viewDidLoad() {
		super.viewDidLoad()
		view.accessibilityIdentifier = "Menu"
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
		tableView.tableHeaderView = makeHeader()
	}

	// MARK: - DataSource

	override func numberOfSections(in tableView: UITableView) -> Int { sections.count }

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		sections[section].items.count
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		sections[section].title
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
		let item = sections[indexPath.section].items[indexPath.row]
		var config = cell.defaultContentConfiguration()
		config.text = item.title
		config.textProperties.font = .monospacedSystemFont(ofSize: 15, weight: .medium)
		config.secondaryText = item.description
		config.secondaryTextProperties.numberOfLines = 2
		config.secondaryTextProperties.color = .secondaryLabel
		cell.contentConfiguration = config
		cell.accessoryType = .disclosureIndicator
		return cell
	}

	// MARK: - Delegate

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		let item = sections[indexPath.section].items[indexPath.row]
		if let tapAction = item.tapAction {
			tapAction(self)
		} else {
			DemoViewController(item: item).show(as: item.presentation)
		}
	}

	// MARK: - Private

	private func makeHeader() -> UIView {
		let titleLabel = UILabel()
		titleLabel.text = "VDPresent"
		titleLabel.font = .monospacedSystemFont(ofSize: 32, weight: .bold)
		titleLabel.textAlignment = .center

		let subtitleLabel = UILabel()
		subtitleLabel.text = "Interactive Documentation"
		subtitleLabel.font = .systemFont(ofSize: 15)
		subtitleLabel.textColor = .secondaryLabel
		subtitleLabel.textAlignment = .center

		// tableHeaderView does not support AutoLayout directly — UIKit assigns it width=0
		// on the first pass before the table knows its own width, causing constraint conflicts.
		// Use a plain UIView with frame-based layout as the header container instead.
		let container = TableHeaderView(height: 114)
		for label in [titleLabel, subtitleLabel] {
			label.translatesAutoresizingMaskIntoConstraints = false
			container.addSubview(label)
		}
		NSLayoutConstraint.activate([
			titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 36),
			titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

			subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
			subtitleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
		])
		return container
	}
}

// MARK: - Stack section

/// Builds the Stack demo items. Extracted to a free function to keep the sections array readable.
/// @ai-generated(solo)
private func stackSectionItems() -> [DemoItem] {
	[
		// Demo: show() — push controllers one by one, navigate with swipe
		.init(
			title: "show(_:as:) — build a stack",
			description: "Each controller is pushed individually. Swipe from the edge to go back.",
			code: "controller.show(as: .push)",
			presentation: .push,
			tapAction: { _ in
				let step3 = StackStepViewController(
					stepTitle: "Step 3 / 3",
					description: "Swipe from the right edge to go back through the stack.",
					code: "",
					actions: [
						.init(title: "Dismiss all", style: .secondary, handler: { vc in
							// hide(3): pops step3, step2, step1 back to menu
							vc.stackController?.hide(3)
						}),
					]
				)
				let step2 = StackStepViewController(
					stepTitle: "Step 2 / 3",
					description: "One more push to go deeper.",
					code: "controller.show(as: .push)",
					actions: [
						.init(title: "Push Step 3", style: .primary, handler: { _ in
							step3.show(as: .push)
						}),
					]
				)
				let step1 = StackStepViewController(
					stepTitle: "Step 1 / 3",
					description: "Push another controller on top of this one.",
					code: "controller.show(as: .push)",
					actions: [
						.init(title: "Push Step 2", style: .primary, handler: { _ in
							step2.show(as: .push)
						}),
					]
				)
				step1.show(as: .push)
			}
		),

		// Demo: hide(_ count:) — pop multiple controllers at once
		.init(
			title: "hide(_ count:) — pop multiple at once",
			description: "Build a stack of 3, then call hide(3) to pop all of them at once.",
			code: "stackController?.hide(3)",
			presentation: .push,
			tapAction: { _ in
				let depth3 = StackStepViewController(
					stepTitle: "Depth 3",
					description: "The stack now has 3 demo controllers. Popping all at once jumps back to the menu.",
					code: "stackController?.hide(3)",
					actions: [
						.init(title: "hide(3) — pop all", style: .primary, handler: { vc in
							vc.stackController?.hide(3)
						}),
					]
				)
				let depth2 = StackStepViewController(
					stepTitle: "Depth 2",
					description: "Go one level deeper.",
					code: "controller.show(as: .push)",
					actions: [
						.init(title: "Push to Depth 3", style: .primary, handler: { _ in
							depth3.show(as: .push)
						}),
					]
				)
				let depth1 = StackStepViewController(
					stepTitle: "Depth 1",
					description: "Push two more controllers, then pop all three in a single call.",
					code: "controller.show(as: .push)",
					actions: [
						.init(title: "Push to Depth 2", style: .primary, handler: { _ in
							depth2.show(as: .push)
						}),
					]
				)
				depth1.show(as: .push)
			}
		),

		// Demo: mixed presentations — each controller in the stack uses a different animation
		.init(
			title: "Mixed presentations in one stack",
			description: "Each controller is shown with its own presentation: sheet → push → pageSheet → fullScreen.",
			code: "a.show(as: .sheet)\nb.show(as: .push)\nc.show(as: .pageSheet)\nd.show(as: .fullScreen)",
			presentation: .sheet,
			tapAction: { _ in
				let d = StackStepViewController(
					stepTitle: "D — .fullScreen",
					description: "Shown with .fullScreen on top of C.",
					code: "d.show(as: .fullScreen)",
					actions: [
						.init(title: "← Go Back", style: .secondary, handler: { vc in vc.hide() }),
					]
				)
				let c = StackStepViewController(
					stepTitle: "C — .pageSheet",
					description: "Shown with .pageSheet on top of B. Notice B scales behind.",
					code: "c.show(as: .pageSheet)",
					actions: [
						.init(title: "Show D (.fullScreen)", style: .primary, handler: { _ in d.show(as: .fullScreen) }),
						.init(title: "← Go Back", style: .secondary, handler: { vc in vc.hide() }),
					]
				)
				let b = StackStepViewController(
					stepTitle: "B — .push",
					description: "Shown with .push on top of A. Swipe from right edge to go back.",
					code: "b.show(as: .push)",
					actions: [
						.init(title: "Show C (.pageSheet)", style: .primary, handler: { _ in c.show(as: .pageSheet) }),
						.init(title: "← Go Back", style: .secondary, handler: { vc in vc.hide() }),
					]
				)
				let a = StackStepViewController(
					stepTitle: "A — .sheet",
					description: "Shown with .sheet. All four controllers live in the same stack.",
					code: "a.show(as: .sheet)",
					actions: [
						.init(title: "Show B (.push)", style: .primary, handler: { _ in b.show(as: .push) }),
						.init(title: "← Go Back", style: .secondary, handler: { vc in vc.hide() }),
					]
				)
				a.show(as: .sheet)
			}
		),

		// Demo: set(viewControllers:) — replace arbitrary stack state
		.init(
			title: "set(viewControllers:) — replace stack",
			description: "Replace the entire stack with a new array of controllers in one call.",
			code: "stack.set(viewControllers: [a, b, c], as: .push)",
			presentation: .push,
			tapAction: { _ in
				let entry = StackStepViewController(
					stepTitle: "set(viewControllers:)",
					description: "Pressing the button replaces the current stack with [A, B, C] at once — animating to C.",
					code: "stack.set(viewControllers: [menu, a, b, c], as: .push)",
					actions: [
						.init(title: "Replace stack with [A, B, C]", style: .primary, handler: { vc in
							guard let stack = vc.stackController else { return }
							// Keep the menu (first VC); swap everything else for A, B, C
							let menu = stack.viewControllers.first.map { [$0] } ?? []
							let a = StackStepViewController(
								stepTitle: "Controller A",
								description: "Part of the new stack set in one call.",
								code: "",
								actions: [
									.init(title: "← Go Back", style: .secondary, handler: { vc in vc.hide() }),
								]
							)
							let b = StackStepViewController(
								stepTitle: "Controller B",
								description: "Part of the new stack set in one call.",
								code: "",
								actions: [
									.init(title: "← Go Back", style: .secondary, handler: { vc in vc.hide() }),
								]
							)
							let c = StackStepViewController(
								stepTitle: "Controller C",
								description: "The stack was set to [menu, A, B, C] in one call.",
								code: "",
								actions: [
									.init(title: "← Go Back", style: .secondary, handler: { vc in vc.hide() }),
								]
							)
							stack.set(viewControllers: menu + [a, b, c], as: .push)
						}),
					]
				)
				entry.show(as: .push)
			}
		),

		// Demo: multiple pageSheets stacked
		.init(
			title: "Multiple .pageSheet",
			description: "Three pageSheets stacked on top of each other. Each scales the previous one.",
			code: "a.show(as: .pageSheet)\nb.show(as: .pageSheet)\nc.show(as: .pageSheet)",
			presentation: .pageSheet,
			tapAction: { _ in
				let sheetC = StackStepViewController(
					stepTitle: "Sheet C",
					description: "Third pageSheet. Notice how each layer scales the one below.",
					code: "c.show(as: .pageSheet)",
					actions: [
						.init(title: "Dismiss all sheets", style: .primary, handler: { vc in
							vc.stackController?.hide(3)
						}),
						.init(title: "← Go Back", style: .secondary, handler: { vc in vc.hide() }),
					]
				)
				let sheetB = StackStepViewController(
					stepTitle: "Sheet B",
					description: "Second pageSheet stacked on A.",
					code: "b.show(as: .pageSheet)",
					actions: [
						.init(title: "Show Sheet C", style: .primary, handler: { _ in
							sheetC.show(as: .pageSheet)
						}),
						.init(title: "← Go Back", style: .secondary, handler: { vc in vc.hide() }),
					]
				)
				let sheetA = StackStepViewController(
					stepTitle: "Sheet A",
					description: "First pageSheet. Push another on top.",
					code: "a.show(as: .pageSheet)",
					actions: [
						.init(title: "Show Sheet B", style: .primary, handler: { _ in
							sheetB.show(as: .pageSheet)
						}),
						.init(title: "← Go Back", style: .secondary, handler: { vc in vc.hide() }),
					]
				)
				sheetA.show(as: .pageSheet)
			}
		),

		// Demo: push after pageSheet
		.init(
			title: ".push after .pageSheet",
			description: "Show a pageSheet, then push on top of it. Different transitions coexist in the same stack.",
			code: "a.show(as: .pageSheet)\nb.show(as: .push)",
			presentation: .pageSheet,
			tapAction: { _ in
				let pushed = StackStepViewController(
					stepTitle: "Pushed on Sheet",
					description: "This controller was pushed on top of a pageSheet. Swipe from right edge to go back.",
					code: "pushed.show(as: .push)",
					actions: [
						.init(title: "Dismiss all", style: .primary, handler: { vc in
							vc.stackController?.hide(2)
						}),
						.init(title: "← Go Back", style: .secondary, handler: { vc in vc.hide() }),
					]
				)
				let sheet = StackStepViewController(
					stepTitle: "PageSheet",
					description: "Now push a controller on top of this sheet.",
					code: "a.show(as: .pageSheet)",
					actions: [
						.init(title: "Push on top", style: .primary, handler: { _ in
							pushed.show(as: .push)
						}),
						.init(title: "← Go Back", style: .secondary, handler: { vc in vc.hide() }),
					]
				)
				sheet.show(as: .pageSheet)
			}
		),

		// Demo: replace pageSheet with push via set(viewControllers:)
		.init(
			title: ".pageSheet → replace with .push",
			description: "Show a pageSheet, then replace it with a push controller via set(viewControllers:).",
			code: "stack.set(viewControllers: [menu, pushed], as: .push)",
			presentation: .pageSheet,
			tapAction: { _ in
				let sheet = StackStepViewController(
					stepTitle: "PageSheet",
					description: "Tap to replace this pageSheet with a pushed controller.",
					code: "stack.set(viewControllers: [menu, pushed], as: .push)",
					actions: [
						.init(title: "Replace with .push", style: .primary, handler: { vc in
							guard let stack = vc.stackController else { return }
							let menu = stack.viewControllers.first.map { [$0] } ?? []
							let pushed = StackStepViewController(
								stepTitle: "Pushed (replaced sheet)",
								description: "This controller replaced the pageSheet. Swipe from right edge to go back.",
								code: "",
								actions: [
									.init(title: "← Go Back", style: .secondary, handler: { vc in vc.hide() }),
								]
							)
							stack.set(viewControllers: menu + [pushed], as: .push)
						}),
						.init(title: "← Go Back", style: .secondary, handler: { vc in vc.hide() }),
					]
				)
				sheet.show(as: .pageSheet)
			}
		),

		// Demo: random stack mutation
		.init(
			title: "Random stack mutation",
			description: "Each tap builds a random stack with random presentations. Tests arbitrary stack changes.",
			code: "stack.set(viewControllers: random, as: .push)",
			presentation: .push,
			tapAction: { _ in
				/// @ai-generated(solo)
				func makeRandomStep(index: Int, total: Int) -> StackStepViewController {
					let presentations: [(String, UIPresentation)] = [
						(".push", .push),
						(".pageSheet", .pageSheet),
						(".sheet", .sheet),
						(".fullScreen", .fullScreen),
					]
					let (name, _) = presentations[index % presentations.count]
					return StackStepViewController(
						stepTitle: "Random \(index + 1)/\(total) (\(name))",
						description: "Part of a randomly generated stack.",
						code: "",
						actions: [
							.init(title: "Randomize again", style: .primary, handler: { vc in
								randomize(from: vc)
							}),
							.init(title: "← Go Back", style: .secondary, handler: { vc in vc.hide() }),
						]
					)
				}

				/// @ai-generated(solo)
				func randomize(from vc: UIViewController) {
					guard let stack = vc.stackController else { return }
					let presentations: [UIPresentation] = [.push, .pageSheet, .sheet, .fullScreen]
					let count = Int.random(in: 1...4)
					let menu = stack.viewControllers.first.map { [$0] } ?? []
					let controllers = (0..<count).map { i in makeRandomStep(index: i, total: count) }
					let presentation = presentations.randomElement() ?? .push
					stack.set(viewControllers: menu + controllers, as: presentation)
				}

				let entry = StackStepViewController(
					stepTitle: "Random Stack",
					description: "Tap to replace the stack with a random set of controllers and presentations.",
					code: "stack.set(viewControllers: random, as: randomPresentation)",
					actions: [
						.init(title: "Randomize!", style: .primary, handler: { vc in
							randomize(from: vc)
						}),
					]
				)
				entry.show(as: .push)
			}
		),
	]
}

// MARK: - DemoViewController

/// @ai-generated(solo)
final class DemoViewController: UIViewController {

	private let item: DemoItem

	init(item: DemoItem) {
		self.item = item
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) { fatalError() }

	override func viewDidLoad() {
		super.viewDidLoad()
		view.accessibilityIdentifier = item.title
		view.backgroundColor = .systemBackground
		setupLayout()
	}

	// MARK: - Private

	private func setupLayout() {
		let titleLabel = UILabel()
		titleLabel.font = .monospacedSystemFont(ofSize: 22, weight: .bold)
		titleLabel.text = item.title
		titleLabel.numberOfLines = 0

		let descriptionLabel = UILabel()
		descriptionLabel.font = .systemFont(ofSize: 16)
		descriptionLabel.textColor = .secondaryLabel
		descriptionLabel.text = item.description
		descriptionLabel.numberOfLines = 0

		let codeBlock = makeCodeBlock(item.code)

		let topStack = UIStackView(arrangedSubviews: [titleLabel, descriptionLabel, codeBlock])
		topStack.axis = .vertical
		topStack.spacing = 16
		topStack.setCustomSpacing(8, after: titleLabel)

		// Dismiss button — always present so every presentation has a guaranteed exit path
		let dismissButton = UIButton(type: .system)
		dismissButton.setTitle("Dismiss", for: .normal)
		dismissButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
		dismissButton.backgroundColor = .systemBlue
		dismissButton.setTitleColor(.white, for: .normal)
		dismissButton.layer.cornerRadius = 14
		dismissButton.layer.cornerCurve = .continuous
		dismissButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
		dismissButton.addTarget(self, action: #selector(didTapDismiss), for: .touchUpInside)

		view.addSubview(topStack)
		view.addSubview(dismissButton)
		topStack.translatesAutoresizingMaskIntoConstraints = false
		dismissButton.translatesAutoresizingMaskIntoConstraints = false

		NSLayoutConstraint.activate([
			topStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
			topStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
			topStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

			dismissButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
			dismissButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
			dismissButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
		])
	}

	private func makeCodeBlock(_ code: String) -> UIView {
		let container = UIView()
		container.backgroundColor = .secondarySystemBackground
		container.layer.cornerRadius = 12
		container.layer.cornerCurve = .continuous

		let label = UILabel()
		label.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
		label.text = code
		label.numberOfLines = 0
		label.textColor = .label

		container.addSubview(label)
		label.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			label.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
			label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
			label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
			label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),
		])
		return container
	}

	@objc private func didTapDismiss() {
		print("🟢 [Dismiss] tapped on \(view.accessibilityIdentifier ?? "?")")
		hide(animated: true)
	}
}

// MARK: - StackStepViewController

struct StackAction {
	let title: String
	let style: Style
	let handler: (UIViewController) -> Void

	enum Style { case primary, secondary }
}

/// A generic step screen for stack demos. Shows a title, description, optional code block,
/// and a configurable list of action buttons.
/// @ai-generated(solo)
final class StackStepViewController: UIViewController {

	private let stepTitle: String
	private let stepDescription: String
	private let code: String
	private let actions: [StackAction]

	init(stepTitle: String, description: String, code: String, actions: [StackAction]) {
		self.stepTitle = stepTitle
		stepDescription = description
		self.code = code
		self.actions = actions
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) { fatalError() }

	override func viewDidLoad() {
		super.viewDidLoad()
		view.accessibilityIdentifier = stepTitle
		view.backgroundColor = .systemBackground
		setupLayout()
	}

	// MARK: - Private

	private func setupLayout() {
		let titleLabel = UILabel()
		titleLabel.font = .monospacedSystemFont(ofSize: 22, weight: .bold)
		titleLabel.text = stepTitle
		titleLabel.numberOfLines = 0

		let descLabel = UILabel()
		descLabel.font = .systemFont(ofSize: 16)
		descLabel.textColor = .secondaryLabel
		descLabel.text = stepDescription
		descLabel.numberOfLines = 0

		var topViews: [UIView] = [titleLabel, descLabel]
		if !code.isEmpty {
			topViews.append(makeCodeBlock(code))
		}

		let topStack = UIStackView(arrangedSubviews: topViews)
		topStack.axis = .vertical
		topStack.spacing = 16
		topStack.setCustomSpacing(8, after: titleLabel)

		let buttonStack = UIStackView(arrangedSubviews: actions.enumerated().map { index, action in
			makeButton(action, tag: index)
		})
		buttonStack.axis = .vertical
		buttonStack.spacing = 10

		view.addSubview(topStack)
		view.addSubview(buttonStack)
		topStack.translatesAutoresizingMaskIntoConstraints = false
		buttonStack.translatesAutoresizingMaskIntoConstraints = false

		NSLayoutConstraint.activate([
			topStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
			topStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
			topStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

			buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
			buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
			buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
		])
	}

	private func makeButton(_ action: StackAction, tag: Int) -> UIButton {
		let btn = UIButton(type: .system)
		btn.setTitle(action.title, for: .normal)
		btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
		btn.layer.cornerRadius = 14
		btn.layer.cornerCurve = .continuous
		btn.heightAnchor.constraint(equalToConstant: 50).isActive = true
		btn.tag = tag
		switch action.style {
		case .primary:
			btn.backgroundColor = .systemBlue
			btn.setTitleColor(.white, for: .normal)
		case .secondary:
			btn.backgroundColor = .secondarySystemBackground
			btn.setTitleColor(.label, for: .normal)
		}
		btn.addTarget(self, action: #selector(didTapButton(_:)), for: .touchUpInside)
		return btn
	}

	@objc private func didTapButton(_ sender: UIButton) {
		guard sender.tag < actions.count else { return }
		let action = actions[sender.tag]
		print("🟢 [\(action.title)] tapped on \(view.accessibilityIdentifier ?? "?")")
		action.handler(self)
	}

	private func makeCodeBlock(_ code: String) -> UIView {
		let container = UIView()
		container.backgroundColor = .secondarySystemBackground
		container.layer.cornerRadius = 12
		container.layer.cornerCurve = .continuous

		let label = UILabel()
		label.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
		label.text = code
		label.numberOfLines = 0
		label.textColor = .label

		container.addSubview(label)
		label.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			label.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
			label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
			label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
			label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),
		])
		return container
	}
}
