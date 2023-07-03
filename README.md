# VDPresent

## Introduction

VDPresent is a powerful, customizable library for managing view controller transitions and hierarchies in iOS applications. It aims to unify and simplify screen transitions by providing a single way to show/hide view controllers through the UIStackController, making it easier to manage custom transition animations and interactions.

## Features

- [x] Manage view controllers with a stack-based approach similar to `UINavigationController`.
- [x] Customize transitions through `UIPresentation` struct.
- [x] Simplify showing and hiding of view controllers.
- [x] Common transitions like `UIPresentation.push`, `UIPresentation.fullScreen` out of the box.
- [ ] Self-sizing behavior for modals like bottom sheets. (Coming soon)
- [ ] Integration with SwiftUI. (Coming soon)
- [ ] Alternatives to native tab and navigation bars. (Coming soon)
- [ ] Comprehensive Unit and UI tests. (Coming soon)

## Requirements

- iOS 13.0+
- Xcode 11+

## Usage

#### Create a UIStackController

```swift
let rootViewController = YourInitialViewController()
let stackController = UIStackController(rootViewController: rootViewController)
```

#### Show a View Controller

```swift
// global presentation
viewController.show(as: .fullScreen(from: .leading, interactive: true))

// local presentation
stackController.show(viewController, as: .push)
```

#### Hide a View Controller

```swift
viewController.hide()
```

## Upcoming Features

- Self-sizing behavior for modals like bottom sheets.
- Integration with SwiftUI.
- Alternatives to standard tab and navigation bars.
- Comprehensive Unit and UI tests.

## Contribute

We would love for you to contribute to `YourLibrary`, check the `LICENSE` file for more info.
 
## Installation

1. [Swift Package Manager](https://github.com/apple/swift-package-manager)

Create a `Package.swift` file.
```swift
// swift-tools-version:5.7
import PackageDescription

let package = Package(
  name: "SomeProject",
  dependencies: [
    .package(url: "https://github.com/dankinsoid/VDPresent.git", from: "0.27.0")
  ],
  targets: [
    .target(name: "SomeProject", dependencies: ["VDPresent"])
  ]
)
```
```ruby
$ swift build
```

2.  [CocoaPods](https://cocoapods.org)

Add the following line to your Podfile:
```ruby
pod 'VDPresent'
```
and run `pod update` from the podfile directory first.

## Author

dankinsoid, voidilov@gmail.com

## License

VDPresent is available under the MIT license. See the LICENSE file for more info.
