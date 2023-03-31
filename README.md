# swift-ruid

## Snowflake Unique Identifier in Swift.

## Integration

#### Swift Package Manager

You can use [The Swift Package Manager](https://swift.org/package-manager) to install `swift-websocket` by adding the proper description to your `Package.swift` file:

```swift
// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "YOUR_PROJECT_NAME",
    dependencies: [
        .package(url: "https://github.com/sutext/swift-suid.git", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "YOUR_TARGET_NAME",
            dependencies: [
                .product(name: "SUID", package: "swift-suid")
            ],
        ),
    ]
)
```

### usage
``` swift
import SUID

let aid = SUID()
let bid = SUID(.B)
print(aid)
print(bid)  

```
