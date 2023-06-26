import UIKit

class ViewController: UIViewController {

	let button = UIButton(type: .system)

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = [UIColor.systemBlue, .systemRed, .systemPink, .systemOrange, .systemYellow, .systemGreen].randomElement()

		view.addSubview(button)
		button.translatesAutoresizingMaskIntoConstraints = false
		button.addTarget(self, action: #selector(tapShow), for: .touchUpInside)
		button.setTitleColor(.white, for: .normal)
		button.setTitle("Show", for: .normal)
		button.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true
		button.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor).isActive = true

		view.backgroundColor = .white
		let view1 = FView()
		let view2 = FView()
		view.addSubview(view1)
		view.addSubview(view2)

		view1.backgroundColor = .systemYellow.withAlphaComponent(0.9)
		view2.backgroundColor = .systemBlue.withAlphaComponent(0.9)

		view1.rect.backgroundColor = .systemOrange.withAlphaComponent(0.9)
		view2.rect.backgroundColor = .systemGreen.withAlphaComponent(0.9)

		view1.frame = CGRect(x: 0, y: 0, width: 300, height: 500)
		view2.frame = CGRect(x: 50, y: 100, width: 300, height: 500)

		view1.rect.layer.zPosition = 2
		view2.rect.layer.zPosition = 1
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		print("viewWillAppear")
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		print("viewDidAppear")
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		print("viewWillDisappear")
	}

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		print("viewDidDisappear")
	}

	@objc func tapShow(_: Any) {
		let controller = ViewController()
		controller.show()
	}
}
