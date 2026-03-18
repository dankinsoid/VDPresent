import UIKit

extension CGFloat {
	
	var descr: String {
		String(format: "%.2f", self)
	}
}

extension CGSize {
	
	var descr: String {
		"(w: \(width.descr) h: \(height.descr))"
	}
}

extension CGPoint {
	
	var descr: String {
		"(x: \(x.descr) y: \(y.descr))"
	}
}

extension CGRect {
	
	var descr: String {
		"(\(origin.descr) \(size.descr))"
	}
}

extension UIEdgeInsets {
	
	var descr: String {
		var result = "("
		var array: [String] = []
		if top != 0 {
			array.append("t: \(top.descr)")
		}
		if left != 0 {
			array.append("l: \(left.descr)")
		}
		if bottom != 0 {
			array.append("b: \(bottom.descr)")
		}
		if right != 0 {
			array.append("r: \(right.descr)")
		}
		if array.isEmpty {
			return "0"
		}
		result += array.joined(separator: " ")
		result += ")"
		return result
	}
}
