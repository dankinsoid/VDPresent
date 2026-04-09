import SwiftUI

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
				title: ".navigation",
				description: "Previous screen slides back at 30% offset. Swipe from the right edge to go back.",
				code: "controller.show(as: .navigation)",
				presentation: .navigation
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
				title: ".navigation(from: .leading)",
				description: "Navigation from the left — mirrors a back-navigation gesture.",
				code: "controller.show(as: .navigation(from: .leading))",
				presentation: .navigation(from: .leading)
			),
			.init(
				title: ".navigation(from: .bottom)",
				description: "Navigation from the bottom.",
				code: "controller.show(as: .navigation(from: .bottom))",
				presentation: .navigation(from: .bottom)
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
		print("🟢 [Menu] tapped: \(item.title)")
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

/// Builds a 4-screen demo where each screen can push one, push all, pop back, pop to root, or replace the stack.
/// @ai-generated(solo)
private func stackNavigationDemo(title: String, presentation: UIPresentation) -> DemoItem {
	let presentationName = title.components(separatedBy: "— ").last ?? "presentation"
	return .init(
		title: title,
		description: "Four screens with \(presentationName). Push one, push all, pop back, pop to root, or replace.",
		code: "vc.show(as: \(presentationName))\nvc.hide()\nstack.pop(_:)\nstack.set(viewControllers:)",
		presentation: presentation,
		tapAction: { _ in
			let total = 4

			let screens = (1 ... total).map { i in
				StackStepViewController(
					stepTitle: "Screen \(i) / \(total)",
					description: i < total
						? "Push next, push all remaining, go back, or jump to root."
						: "Last screen. Go back, pop to root, or replace the stack.",
					code: "",
					actions: []
				)
			}

			for (i, screen) in screens.enumerated() {
				let index = i + 1
				let remaining = Array(screens[(i + 1)...])
				let actions: [StackAction?] = [
					index < total
						? .init(title: "Push Screen \(index + 1)", style: .primary, handler: { _ in
							_ = screens[i + 1].show(as: presentation)
						})
						: nil,
					remaining.count > 1
						? .init(title: "Push all \(remaining.count) at once", style: .primary, handler: { vc in
							guard let stack = vc.stackController else { return }
							stack.set(viewControllers: stack.viewControllers + remaining, as: presentation)
						})
						: nil,
					.init(title: "set() — replace stack", style: .primary, handler: { vc in
						guard let stack = vc.stackController else { return }
						let menu = stack.viewControllers.first.map { [$0] } ?? []
						let fresh = StackStepViewController(
							stepTitle: "Replaced",
							description: "The entire stack was replaced with set(viewControllers:).",
							code: "stack.set(viewControllers: [menu, this], as: \(presentationName))",
							actions: [
								.init(title: "← Go Back", style: .secondary, handler: { vc in vc.hide() }),
							]
						)
						stack.set(viewControllers: menu + [fresh], as: presentation)
					}),
					index > 1
						? .init(title: "pop(\(index)) — to root", style: .secondary, handler: { vc in
							vc.stackController?.pop(index)
						})
						: nil,
					.init(title: "← Go Back", style: .secondary, handler: { vc in vc.hide() }),
				]
				screen.setActions(actions.compactMap { $0 })
			}

			_ = screens[0].show(as: presentation)
		}
	)
}

/// Builds the Stack demo items. Extracted to a free function to keep the sections array readable.
/// @ai-generated(solo)
private func stackSectionItems() -> [DemoItem] {
	[
		// @ai-generated(solo)
		stackNavigationDemo(title: "Stack — .navigation", presentation: .navigation),
		stackNavigationDemo(title: "Stack — .pageSheet", presentation: .pageSheet),
		stackNavigationDemo(title: "Stack — .sheet", presentation: .sheet),
		stackNavigationDemo(title: "Stack — .pageSheet top", presentation: .pageSheet(from: .top)),

		// Demo: pageSheet with different edges in one stack
		// @ai-generated(solo)
		.init(
			title: ".pageSheet — mixed edges",
			description: "Four pageSheets shown one after another, each from a different edge (bottom, top, leading, trailing) in the same stack.",
			code: "a.show(as: .pageSheet(from: .bottom))\nb.show(as: .pageSheet(from: .top))\nc.show(as: .pageSheet(from: .leading))\nd.show(as: .pageSheet(from: .trailing))",
			presentation: .pageSheet,
			tapAction: { _ in
				let edges: [(String, Edge)] = [
					("bottom", .bottom),
					("top", .top),
					("leading", .leading),
					("trailing", .trailing),
				]
				let total = edges.count
				let screens = edges.enumerated().map { i, pair in
					StackStepViewController(
						stepTitle: "Sheet \(i + 1)/\(total) — from .\(pair.0)",
						description: "pageSheet shown from .\(pair.0). Push the next one or swipe to dismiss.",
						code: "vc.show(as: .pageSheet(from: .\(pair.0)))",
						actions: []
					)
				}
				for (i, screen) in screens.enumerated() {
					var actions: [StackAction] = []
					if i + 1 < total {
						let next = screens[i + 1]
						let nextEdge = edges[i + 1]
						actions.append(.init(title: "Push .\(nextEdge.0)", style: .primary, handler: { _ in
							_ = next.show(as: .pageSheet(from: nextEdge.1))
						}))
					}
					actions.append(.init(title: "← Go Back", style: .secondary, handler: { vc in vc.hide() }))
					screen.setActions(actions)
				}
				_ = screens[0].show(as: .pageSheet(from: edges[0].1))
			}
		),

		// Demo: push after pageSheet
		.init(
			title: ".navigation after .pageSheet",
			description: "Show a pageSheet, then navigate on top of it. Different transitions coexist in the same stack.",
			code: "a.show(as: .pageSheet)\nb.show(as: .navigation)",
			presentation: .pageSheet,
			tapAction: { _ in
				let pushed = StackStepViewController(
					stepTitle: "Pushed on Sheet",
					description: "This controller was pushed on top of a pageSheet. Swipe from right edge to go back.",
					code: "pushed.show(as: .navigation)",
					actions: [
						.init(title: "Dismiss all", style: .primary, handler: { vc in
							vc.stackController?.pop(2)
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
							pushed.show(as: .navigation)
						}),
						.init(title: "← Go Back", style: .secondary, handler: { vc in vc.hide() }),
					]
				)
				sheet.show(as: .pageSheet)
			}
		),

		replaceDemo(from: (.pageSheet, "pageSheet"), to: (.navigation, "navigation")),
		replaceDemo(from: (.navigation, "navigation"), to: (.pageSheet, "pageSheet")),
		replaceDemo(from: (.pageSheet, "pageSheet"), to: (.pageSheet(from: .top), "pageSheet(from: .top)")),
		replaceDemo(from: (.navigation, "navigation"), to: (.pageSheet, "pageSheet")),

		// Demo: random stack mutation
		.init(
			title: "Random stack mutation",
			description: "Each tap builds a random stack with random presentations. Tests arbitrary stack changes.",
			code: "stack.set(viewControllers: random, as: .navigation)",
			presentation: .navigation,
			tapAction: { _ in
				// @ai-generated(solo)
				func makeRandomStep(index: Int, total: Int) -> StackStepViewController {
					let presentations: [(String, UIPresentation)] = [
						(".navigation", .navigation),
						(".pageSheet", .pageSheet),
						(".sheet", .sheet),
						(".fullScreen", .fullScreen),
					]
					let (name, presentation) = presentations[index % presentations.count]
					let vc = StackStepViewController(
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
					vc.defaultPresentation = presentation.with(animation: .default(1))
					return vc
				}

				// @ai-generated(guided)
				func randomize(from vc: UIViewController) {
					guard let stack = vc.stackController else { return }
					let menu = stack.viewControllers.first.map { [$0] } ?? []
					// Existing non-menu controllers that can be kept
					let existing = Array(stack.viewControllers.dropFirst())
					let keepCount = Int.random(in: 0 ... existing.count)
					let kept = Array(existing.prefix(keepCount))
					let newCount = Int.random(in: (kept.isEmpty ? 1 : 0) ... 7)
					let total = kept.count + newCount
					let newControllers = (0 ..< newCount).map { i in
						makeRandomStep(index: kept.count + i, total: total)
					}
					stack.set(viewControllers: menu + (kept + newControllers).shuffled())
				}

				let entry = StackStepViewController(
					stepTitle: "Random Stack",
					description: "Tap to replace the stack with a random set of controllers and presentations.",
					code: "stack.set(viewControllers: random, as: randomPresentation)",
					actions: [
						.init(title: "Randomize!", style: .primary, handler: { vc in
							randomize(from: vc)
						}),
						.init(title: "← Go Back", style: .secondary, handler: { vc in vc.hide() }),
					]
				)
				entry.show(as: .navigation)
			}
		),
	]
}

/// @ai-generated(solo)
private func replaceDemo(
	from initial: (UIPresentation, String),
	to replacement: (UIPresentation, String),
	suffix: String? = nil
) -> DemoItem {
	let (initialPres, initialName) = initial
	let (replacementPres, replacementName) = replacement
	let titleSuffix = suffix.map { " (\($0))" } ?? ""
	return .init(
		title: ".\(initialName) → .\(replacementName)\(titleSuffix)",
		description: "Show .\(initialName), then replace with .\(replacementName) via set(viewControllers:).",
		code: "stack.set(viewControllers: [menu, new], as: .\(replacementName))",
		presentation: initialPres,
		tapAction: { _ in
			let step = StackStepViewController(
				stepTitle: ".\(initialName)",
				description: "Tap to replace with .\(replacementName).",
				code: "stack.set(viewControllers: [menu, new], as: .\(replacementName))",
				actions: [
					.init(title: "Replace with .\(replacementName)", style: .primary, handler: { vc in
						guard let stack = vc.stackController else { return }
						let menu = stack.viewControllers.first.map { [$0] } ?? []
						let replaced = StackStepViewController(
							stepTitle: ".\(replacementName) (replaced)",
							description: "Replaced .\(initialName). Dismiss to go back.",
							code: "",
							actions: [
								.init(title: "← Go Back", style: .secondary, handler: { vc in vc.hide() }),
							]
						)
						stack.set(viewControllers: menu + [replaced], as: replacementPres.with(animation: .default(1)))
					}),
					.init(title: "← Go Back", style: .secondary, handler: { vc in vc.hide() }),
				]
			)
			step.show(as: initialPres)
		}
	)
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
	private var actions: [StackAction]

	init(stepTitle: String, description: String, code: String, actions: [StackAction]) {
		self.stepTitle = stepTitle
		stepDescription = description
		self.code = code
		self.actions = actions
		super.init(nibName: nil, bundle: nil)
	}

	/// Allows configuring actions after init (e.g. when screens reference each other).
	func setActions(_ newActions: [StackAction]) {
		actions = newActions
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
		print("🟢 [\(action.title)] tapped on \(sender.title(for: .normal) ?? view.accessibilityIdentifier ?? "?")")
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
