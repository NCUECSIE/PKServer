// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "PKServer",
    dependencies: [
        .Package(url: "https://github.com/IBM-Swift/Kitura.git", majorVersion: 1, minor: 7),
        .Package(url: "https://github.com/IBM-Swift/HeliumLogger.git", majorVersion: 1, minor: 7),
        .Package(url: "https://github.com/OpenKitten/MongoKitten.git", "4.0.0-vaportls")
    ]
)
