import UIKit

class ViewController: UIViewController {

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
	override func viewDidLoad() {
		super.viewDidLoad()
        view.backgroundColor = [
            UIColor.systemBlue,
            .systemRed,
            .systemPink,
            .systemOrange,
            .systemYellow,
            .systemGreen
        ].randomElement()

        let showButton = UIButton(type: .system)
        showButton.addTarget(self, action: #selector(tapShow), for: .touchUpInside)
        showButton.setTitleColor(.white, for: .normal)
        showButton.setTitle("Show", for: .normal)
        
        let hideButton = UIButton(type: .system)
        hideButton.addTarget(self, action: #selector(tapHide), for: .touchUpInside)
        hideButton.setTitleColor(.white, for: .normal)
        hideButton.setTitle("Hide", for: .normal)
        
        let stackView = UIStackView()
        view.addSubview(stackView)
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        
        stackView.addArrangedSubview(showButton)
        stackView.addArrangedSubview(hideButton)
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
//        controller.view.safeAreaLayoutGuide.heightAnchor
//            .constraint(equalToConstant: 500).isActive = true
        
        let presentations: [UIPresentation] = [
            .sheet, .pageSheet, .push, .fullScreen
        ]
        controller.show(as: presentations.randomElement()?.with(animation: .default), animated: true)
	}
    
    @objc func tapHide(_: Any) {
        hide(animated: true)
    }
}
