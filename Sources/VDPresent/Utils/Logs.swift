import SwiftUI

// MARK: - Debug logging

#if VDPRESENT_LOG
/// Logs a summary of each visible controller's transform state after a phase.
///
/// Output format — one line per VC:
/// ```
/// [phase] Menu: center (layers=5, remaining)
/// [phase] Screen 1: ty=-23 sx=0.940 (layers=4, departing)
/// ```
func logTransitionState(
	_ phase: String,
	allVisible: [UIViewController],
	controllers: UIPresentation.Context.Controllers,
	context: @escaping (UIViewController) -> UIPresentation.Context
) {
	let toRemove = Set(controllers.toRemove.map(ObjectIdentifier.init))
	let toSet = Set(controllers.to.map(ObjectIdentifier.init))
	var lines: [String] = []
	for vc in allVisible {
		let ctx = context(vc)
		let name = vc.view.accessibilityIdentifier ?? String(describing: type(of: vc))
		let transform = fmtTransform(ctx.view)
		let id = ObjectIdentifier(vc)
		let role: String
		if toRemove.contains(id) {
			role = "departing"
		} else if !toSet.contains(id) {
			role = "inserting"
		} else {
			role = "remaining"
		}
		let frame = fmtFrame(ctx.view)
		lines.append("  \(name): \(transform) \(frame) \(role)")
	}
	print("[\(phase)]\n\(lines.joined(separator: "\n"))")
}

func fmtTransform(_ view: UIView) -> String {
	let t = view.affineTransform
	let sx = sqrt(t.a * t.a + t.c * t.c)
	let sy = sqrt(t.b * t.b + t.d * t.d)
	var parts: [String] = []
	if t.tx != 0 { parts.append("tx=\(Int(t.tx))") }
	if t.ty != 0 { parts.append("ty=\(Int(t.ty))") }
	if abs(sx - 1) > 0.001 || abs(sy - 1) > 0.001 {
		parts.append("sx=\(String(format: "%.3f", sx)) sy=\(String(format: "%.3f", sy))")
	}
	return parts.isEmpty ? "center" : parts.joined(separator: " ")
}

/// Window-relative insets: only non-zero edges, e.g. "{t=59 b=34}" or "{l=10 r=10 b=802}".
func fmtFrame(_ view: UIView) -> String {
	guard let window = view.window else { return "{detached}" }
	let r = view.convert(view.bounds, to: nil)
	let wb = window.bounds
	var parts: [String] = []
	let t = Int(r.minY)
	let b = Int(wb.maxY - r.maxY)
	let l = Int(r.minX)
	let ri = Int(wb.maxX - r.maxX)
	if t != 0 { parts.append("t=\(t)") }
	if l != 0 { parts.append("l=\(l)") }
	if ri != 0 { parts.append("r=\(ri)") }
	if b != 0 { parts.append("b=\(b)") }
	return "{\(parts.isEmpty ? "full" : parts.joined(separator: " "))}"
}

/// Window-relative insets from presentation layer frame, same format as fmtFrame.
func fmtPresentationFrame(_ pLayer: CALayer, in view: UIView) -> String {
	guard let window = view.window else { return "{detached}" }
	// presentation() frame is in superlayer coords — convert to window.
	let r: CGRect
	if let superlayer = pLayer.superlayer {
		r = superlayer.convert(pLayer.frame, to: nil)
	} else {
		r = pLayer.frame
	}
	let wb = window.bounds
	var parts: [String] = []
	let t = Int(r.minY)
	let b = Int(wb.maxY - r.maxY)
	let l = Int(r.minX)
	let ri = Int(wb.maxX - r.maxX)
	if t != 0 { parts.append("t=\(t)") }
	if l != 0 { parts.append("l=\(l)") }
	if ri != 0 { parts.append("r=\(ri)") }
	if b != 0 { parts.append("b=\(b)") }
	return "{\(parts.isEmpty ? "full" : parts.joined(separator: " "))}"
}

func fmtMaskedCorners(_ mc: CACornerMask) -> String {
	var parts: [String] = []
	if mc.contains(.layerMinXMinYCorner) { parts.append("TL") }
	if mc.contains(.layerMaxXMinYCorner) { parts.append("TR") }
	if mc.contains(.layerMinXMaxYCorner) { parts.append("BL") }
	if mc.contains(.layerMaxXMaxYCorner) { parts.append("BR") }
	return parts.isEmpty ? "none" : parts.joined(separator: "|")
}

func fmtCATransform(_ t: CGAffineTransform) -> String {
	let sx = sqrt(t.a * t.a + t.c * t.c)
	let sy = sqrt(t.b * t.b + t.d * t.d)
	var parts: [String] = []
	if t.tx != 0 { parts.append("tx=\(Int(t.tx))") }
	if t.ty != 0 { parts.append("ty=\(Int(t.ty))") }
	if abs(sx - 1) > 0.001 || abs(sy - 1) > 0.001 {
		parts.append("sx=\(String(format: "%.3f", sx)) sy=\(String(format: "%.3f", sy))")
	}
	return parts.isEmpty ? "center" : parts.joined(separator: " ")
}
#endif
