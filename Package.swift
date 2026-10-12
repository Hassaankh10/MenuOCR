// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "MenuOCR", platforms: [.macOS(.v13)], products: [.executable(name: "MenuOCR", targets: ["MenuOCR"])], targets: [.executableTarget(name: "MenuOCR"), .testTarget(name: "MenuOCRTests", dependencies: ["MenuOCR"])])
