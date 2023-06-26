import SwiftUI

extension CACornerMask {

	static func edge(_ edge: Edge) -> CACornerMask {
		switch edge {
		case .top: return [.layerMaxXMinYCorner, .layerMinXMinYCorner]
		case .leading: return UIApplication.shared.isLtrDirection
			? [.layerMinXMinYCorner, .layerMinXMaxYCorner]
			: [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
		case .bottom: return [.layerMaxXMaxYCorner, .layerMinXMaxYCorner]
		case .trailing: return UIApplication.shared.isLtrDirection
			? [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
			: [.layerMinXMinYCorner, .layerMinXMaxYCorner]
		}
	}
}
