# VDPresent

[![CI Status](https://img.shields.io/travis/dankinsoid/VDPresent.svg?style=flat)](https://travis-ci.org/dankinsoid/VDPresent)
[![Version](https://img.shields.io/cocoapods/v/VDPresent.svg?style=flat)](https://cocoapods.org/pods/VDPresent)
[![License](https://img.shields.io/cocoapods/l/VDPresent.svg?style=flat)](https://cocoapods.org/pods/VDPresent)
[![Platform](https://img.shields.io/cocoapods/p/VDPresent.svg?style=flat)](https://cocoapods.org/pods/VDPresent)


## Description
This repository provides

## Example

```swift

```
## Usage

 
## Installation

1. [Swift Package Manager](https://github.com/apple/swift-package-manager)

Create a `Package.swift` file.
```swift
// swift-tools-version:5.7
import PackageDescription

let package = Package(
  name: "SomeProject",
  dependencies: [
    .package(url: "https://github.com/dankinsoid/VDPresent.git", from: "0.11.0")
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
