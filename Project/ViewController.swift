import UIKit

class ViewController: UIViewController {

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = [UIColor.systemBlue, .systemRed, .systemPink, .systemOrange, .systemYellow, .systemGreen].randomElement()

        let showButton = UIButton(type: .system)
		view.addSubview(showButton)
        showButton.translatesAutoresizingMaskIntoConstraints = false
        showButton.addTarget(self, action: #selector(tapShow), for: .touchUpInside)
        showButton.setTitleColor(.white, for: .normal)
        showButton.setTitle("Show", for: .normal)
        showButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true
        showButton.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor).isActive = true
        
        let hideButton = UIButton(type: .system)

        view.addSubview(hideButton)
        hideButton.translatesAutoresizingMaskIntoConstraints = false
        hideButton.addTarget(self, action: #selector(tapHide), for: .touchUpInside)
        hideButton.setTitleColor(.white, for: .normal)
        hideButton.setTitle("Hide", for: .normal)
        hideButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true
        hideButton.topAnchor.constraint(equalTo: showButton.bottomAnchor).isActive = true
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
	}

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
	}

	@objc func tapShow(_: Any) {
		let controller = ViewController()
        let presentations = [UIPresentation.fullScreen, .push, .pageSheet, .fullScreen(from: .top)]
//        controller.view.safeAreaLayoutGuide.heightAnchor.constraint(equalToConstant: 200).isActive = true
//        present(controller, animated: true)
        controller.show(as: presentations.randomElement()?.with(animation: .default(1)), animated: true)
//        navigationController?.pushViewController(controller, animated: true)
	}
    
    @objc func tapHide(_: Any) {
        hide(animated: true)
    }
}
