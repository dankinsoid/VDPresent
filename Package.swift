// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "VDPresent",
	platforms: [
		.iOS(.v13),
	],
	products: [
		.library(name: "VDPresent", targets: ["VDPresent"]),
	],
	dependencies: [
		.package(url: "https://github.com/dankinsoid/VDTransition.git", from: "1.19.0"),
	],
	targets: [
		.target(
			name: "VDPresent",
			dependencies: [
				"VDTransition",
			]
		),
	]
)
