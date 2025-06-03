# DicyaninMultiDeviceMP

A Swift package for synchronizing 3D content across multiple Apple devices using MultipeerConnectivity framework. This package provides the foundation for creating shared AR/VR experiences between visionOS and iOS devices.

## Features

- Real-time entity synchronization across devices
- Support for 3D model data transfer
- Automatic device discovery and connection management
- Transform synchronization for interactive objects
- Built on top of RealityKit and MultipeerConnectivity

## Installation

### Swift Package Manager

Add the package to your Xcode project:

1. In Xcode, go to File > Add Packages...
2. Enter the package repository URL
3. Select the version you want to use
4. Click Add Package

## Usage

### Basic Setup

```swift
import DicyaninMultiDeviceMP
import RealityKit

// Create a manager instance
let manager = MultiDeviceManager(displayName: "YourAppName")

// Set up your RealityView
RealityView { content in
    // Create a sync root entity
    let syncRoot = Entity()
    syncRoot.name = "SyncRoot"
    syncRoot.components.set(SyncComponent(id: "SyncRoot"))
    
    // Add your content
    content.add(syncRoot)
    
    // Start observing
    manager.startObserving(rootEntity: syncRoot)
    
    // Set up entity observation
    if manager.entityObservation == nil {
        manager.entityObservation = EntityObservation(
            rootEntity: syncRoot,
            onDataReceived: { data in
                manager.entityObservation?.handleReceivedData(data)
            }
        )
    }
}
```

### Synchronizing Entities

```swift
// Create an entity with sync components
let entity = Entity()
entity.name = "MyEntity"

// Add sync component
let syncId = "Entity_\(UUID().uuidString)"
entity.components.set(SyncComponent(id: syncId))

// Add model sync component if needed
if let modelData = try? Data(contentsOf: modelURL) {
    entity.components.set(SyncModelComponent(modelData: modelData))
}

// Add to your scene
rootEntity.addChild(entity)

// Broadcast updates
if let entityObservation = manager.entityObservation {
    let transform = SyncTransform(from: entity.transform)
    entityObservation.broadcastTransform(for: entity, transform: transform)
}
```

### Connection Management

```swift
// Add the connection view to your SwiftUI view
MultiDeviceConnectionView(displayName: "YourAppName")
    .background(.ultraThinMaterial)

// Monitor connection state
.onChange(of: manager.isConnected) { newValue in
    print("Connection state: \(newValue)")
}
.onChange(of: manager.connectedPeers) { newPeers in
    print("Connected peers: \(newPeers.count)")
}
```

## Components

### MultiDeviceManager

The main class that handles device discovery and connection management.

```swift
class MultiDeviceManager {
    var isConnected: Bool
    var connectedPeers: [MCPeerID]
    var entityObservation: EntityObservation?
    
    func startObserving(rootEntity: Entity)
    func stopObserving()
}
```

### EntityObservation

Manages entity synchronization across devices.

```swift
class EntityObservation {
    func broadcastTransform(for entity: Entity, transform: SyncTransform)
    func handleReceivedData(_ data: Data)
}
```

### SyncComponent

Tracks entity state and updates.

```swift
struct SyncComponent: Component {
    var id: String
    var timestamp: TimeInterval
    var sequenceNumber: Int
}
```

### SyncModelComponent

Handles 3D model data synchronization.

```swift
struct SyncModelComponent: Component {
    var modelURL: URL?
    var modelData: Data?
}
```

## Best Practices

1. **Entity Naming**
   - Use unique names for entities
   - Include UUID in sync IDs to prevent conflicts

2. **Model Synchronization**
   - Always include model data when adding new 3D models
   - Use appropriate collision shapes for interaction

3. **Connection Management**
   - Handle connection state changes appropriately
   - Provide user feedback for connection status

4. **Performance**
   - Only broadcast transform updates when necessary
   - Use appropriate update frequency for your use case

## Requirements

- iOS 17.0+
- visionOS 1.0+
- Swift 5.9+
- Xcode 15.0+

## License

This package is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Author

Hunter Harris
- GitHub: [@hunterh37](https://github.com/hunterh37)
- Website: [dicyaninlabs.com](https://dicyaninlabs.com) 