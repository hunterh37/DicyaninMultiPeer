# DicyaninMultiDeviceMP

A Swift package for synchronizing RealityKit entities between visionOS and iOS devices using MultipeerConnectivity.

## Features

- 🔄 Automatic device discovery and connection
- 🎯 Full transform synchronization (position, rotation, scale)
- 🌐 Support for multiple entities
- 📱 Compatible with both visionOS and iOS
- 🎨 Easy-to-use SwiftUI views
- 🔒 Secure encrypted connections

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/hunterh37/DicyaninMultiDeviceMP.git", from: "1.0.0")
]
```

Or add it directly in Xcode:
1. File > Add Packages...
2. Enter the repository URL
3. Select the version you want to use

## Required Privacy Permissions

Add the following to your `Info.plist` file to enable MultipeerConnectivity:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>This app uses the local network to discover and connect to nearby devices for multi-device synchronization.</string>
<key>NSBonjourServices</key>
<array>
    <string>_dicyanin-multidevice._tcp</string>
    <string>_dicyanin-multidevice._udp</string>
</array>
```

These permissions are required for:
- Device discovery
- Local network communication
- Service advertising
- Peer-to-peer connections

## Usage

### Basic Setup

First, import the package in your Swift file:

```swift
import DicyaninMultiDeviceMP
```

### Using the SwiftUI Views

#### 1. Basic Connection View

The simplest way to add multi-device support is to use the `MultiDeviceConnectionView`:

```swift
struct ContentView: View {
    var body: some View {
        MultiDeviceConnectionView(displayName: "MyApp")
    }
}
```

This will show a connection status indicator and list of connected devices.

#### 2. RealityView Integration

For apps using RealityKit, use the `MultiDeviceRealityView`. Here's a complete example:

```swift
struct ARContentView: View {
    // Create your root entity
    let rootEntity = Entity()
    
    init() {
        // Add some content to your root entity
        let box = ModelEntity(mesh: .generateBox(size: 0.3))
        box.position = SIMD3(x: 0, y: 1.5, z: -2)
        rootEntity.addChild(box)
    }
    
    var body: some View {
        MultiDeviceRealityView(
            displayName: "MyApp",
            rootEntity: rootEntity
        )
    }
}
```

#### 3. Custom Integration

If you need more control, you can use the `MultiDeviceManager` directly:

```swift
class YourViewModel: ObservableObject {
    private let manager = MultiDeviceManager(displayName: "MyApp")
    private let rootEntity = Entity()
    
    init() {
        // Add your content
        let box = ModelEntity(mesh: .generateBox(size: 0.3))
        box.position = SIMD3(x: 0, y: 1.5, z: -2)
        rootEntity.addChild(box)
        
        // Start observing
        manager.startObserving(rootEntity: rootEntity)
    }
}
```

### Example: Complete App Integration

Here's a complete example showing how to integrate the package into a visionOS/iOS app:

```swift
import SwiftUI
import RealityKit
import DicyaninMultiDeviceMP

struct ContentView: View {
    // Create your root entity
    let rootEntity = Entity()
    
    init() {
        // Add some 3D content
        let box = ModelEntity(mesh: .generateBox(size: 0.3))
        box.position = SIMD3(x: 0, y: 1.5, z: -2)
        rootEntity.addChild(box)
    }
    
    var body: some View {
        ZStack {
            // Your 3D content
            RealityView { content in
                // Create a sync root entity
                let syncRoot = Entity()
                syncRoot.name = "SyncRoot"
                
                // Add your content as a child
                syncRoot.addChild(rootEntity)
                
                // Add to the scene
                content.add(syncRoot)
            }
            
            // Multi-device connection UI
            VStack {
                Spacer()
                MultiDeviceConnectionView(displayName: "MyApp")
                    .background(.ultraThinMaterial)
            }
        }
    }
}
```

### Settings View

The package includes a settings view that can be presented as a sheet:

```swift
struct ContentView: View {
    @State private var isShowingSettings = false
    @StateObject private var manager = MultiDeviceManager(displayName: "MyApp")
    
    var body: some View {
        Button("Settings") {
            isShowingSettings.toggle()
        }
        .sheet(isPresented: $isShowingSettings) {
            MultiDeviceSettingsView(manager: manager)
        }
    }
}
```

## Requirements

- iOS 15.0+
- visionOS 1.0+
- Xcode 15.0+
- Swift 5.9+

## License

This package is available under the MIT license. See the LICENSE file for more info.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Author

Hunter Harris
- GitHub: [@hunterh37](https://github.com/hunterh37)
- Website: [dicyaninlabs.com](https://dicyaninlabs.com) 