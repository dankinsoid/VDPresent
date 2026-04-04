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

extension CGAffineTransform {

	var descr: String {
		var parts: [String] = []
		if tx != 0 { parts.append("tx: \(tx.descr)") }
		if ty != 0 { parts.append("ty: \(ty.descr)") }
		let sx = sqrt(a * a + c * c)
		let sy = sqrt(b * b + d * d)
		if abs(sx - 1) > 0.001 { parts.append("sx: \(sx.descr)") }
		if abs(sy - 1) > 0.001 { parts.append("sy: \(sy.descr)") }
		return parts.isEmpty ? "identity" : "(\(parts.joined(separator: " ")))"
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
