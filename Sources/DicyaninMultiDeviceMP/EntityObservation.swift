import Foundation
import RealityKit
import Combine

// MARK: - ECS Components

public struct SyncComponent: Component {
    public var id: String
    public var timestamp: TimeInterval
    public var sequenceNumber: Int
    
    public init(id: String, timestamp: TimeInterval = Date().timeIntervalSince1970, sequenceNumber: Int = 0) {
        self.id = id
        self.timestamp = timestamp
        self.sequenceNumber = sequenceNumber
    }
}

public struct SyncModelComponent: Component {
    public var modelURL: URL?
    public var modelData: Data?
    
    public init(modelURL: URL? = nil, modelData: Data? = nil) {
        self.modelURL = modelURL
        self.modelData = modelData
    }
}

// MARK: - Entity Observation

public class EntityObservation {
    private let rootEntity: Entity
    private let onDataReceived: (Data) -> Void
    private var entityObservers: [Entity: AnyCancellable] = [:]
    private let stateQueue = DispatchQueue(label: "com.dicyanin.entityobservation.state", qos: .userInitiated)
    
    public init(rootEntity: Entity, onDataReceived: @escaping (Data) -> Void) {
        self.rootEntity = rootEntity
        self.onDataReceived = onDataReceived
        observeEntity(rootEntity)
    }
    
    deinit {
        // Cleanup if needed
    }
    
    // MARK: - Private Methods
    
    private func observeEntity(_ entity: Entity) {
        // Add sync component if not present
        if entity.components[SyncComponent.self] == nil {
            // Ensure entity has a name
            if entity.name.isEmpty {
                entity.name = "Entity_\(UUID().uuidString)"
            }
            var syncComponent = SyncComponent(id: entity.name)
            entity.components[SyncComponent.self] = syncComponent
        }
        
        // Store reference to entity for periodic updates
        entityObservers[entity] = AnyCancellable {
            // Cleanup if needed
        }
        
        // Observe children
        for child in entity.children {
            observeEntity(child)
        }
    }
    
    public func broadcastTransform(for entity: Entity, transform: SyncTransform, includeModel: Bool = false) {
        guard let syncComponent = entity.components[SyncComponent.self] else { return }
        
        let currentTime = Date().timeIntervalSince1970
        let modelComponent = includeModel ? entity.components[SyncModelComponent.self] : nil
        
        print("Broadcasting transform for entity \(entity.name):")
        print("  Position: \(entity.transform.translation)")
        print("  Rotation: \(entity.transform.rotation.vector)")
        print("  Scale: \(entity.transform.scale)")
        print("  Sequence: \(syncComponent.sequenceNumber + 1)")
        print("  Include Model: \(includeModel)")
        
        // Create sync data with current transform
        let syncData = SyncData(
            id: syncComponent.id,
            timestamp: currentTime,
            sequenceNumber: syncComponent.sequenceNumber + 1,
            transform: SyncTransform(from: entity.transform),
            modelData: modelComponent?.modelData,
            modelURL: modelComponent?.modelURL
        )
        
        do {
            let data = try JSONEncoder().encode(syncData)
            onDataReceived(data)
        } catch {
            print("Error broadcasting transform: \(error)")
        }
    }
    
    public func handleReceivedData(_ data: Data) {
        do {
            let syncData = try JSONDecoder().decode(SyncData.self, from: data)
            handleSyncData(syncData)
        } catch {
            print("Error decoding sync data: \(error)")
        }
    }
    
    private func handleSyncData(_ data: SyncData) {
        if let existingEntity = findEntity(withId: data.id) {
            updateExistingEntity(existingEntity, with: data)
        } else {
            createNewEntity(from: data)
        }
    }
    
    private func updateExistingEntity(_ entity: Entity, with data: SyncData) {
        guard var syncComponent = entity.components[SyncComponent.self] else { return }
        
        print("Received transform update for entity \(syncComponent.id):")
        print("  Current timestamp: \(syncComponent.timestamp)")
        print("  New timestamp: \(data.timestamp)")
        print("  Current sequence: \(syncComponent.sequenceNumber)")
        print("  New sequence: \(data.sequenceNumber)")
        
        // Only update if data is newer or has higher sequence number
        let shouldUpdate = data.timestamp > syncComponent.timestamp || 
                          (data.timestamp == syncComponent.timestamp && data.sequenceNumber > syncComponent.sequenceNumber)
        
        if shouldUpdate {
            print("Applying transform update:")
            print("  Old position: \(entity.transform.translation)")
            print("  New position: \(data.transform.translation)")
            
            syncComponent.timestamp = data.timestamp
            syncComponent.sequenceNumber = data.sequenceNumber
            entity.components[SyncComponent.self] = syncComponent
            
            // Update transform immediately
            entity.transform = data.transform.realityKitTransform
        } else {
            print("Ignoring transform update - not newer")
        }
    }
    
    private func createNewEntity(from data: SyncData) {
        let entity = Entity()
        
        // Add sync component
        let syncComponent = SyncComponent(
            id: data.id,
            timestamp: data.timestamp,
            sequenceNumber: data.sequenceNumber
        )
        entity.components[SyncComponent.self] = syncComponent
        
        // Set transform
        entity.transform = data.transform.realityKitTransform
        
        print("Create new 3D model for entity \(syncComponent.id)")
        // Add model if data exists - only load once during creation
        if let modelData = data.modelData {
            print("Found 3d model data")
            Task { @MainActor in
                if let tempURL = createTemporaryURL(from: modelData),
                   let model = try? ModelEntity.load(contentsOf: tempURL) {
                    entity.addChild(model)
                    print("Loading new 3D model for entity \(syncComponent.id)")
                }
            }
        }
        
        // Add to root
        rootEntity.addChild(entity)
    }
    
    private func findEntity(withId id: String) -> Entity? {
        // Search recursively through all children
        func searchInEntity(_ entity: Entity) -> Entity? {
            // Check if this entity has the matching ID
            if entity.components[SyncComponent.self]?.id == id {
                return entity
            }
            
            // Search in children
            for child in entity.children {
                if let found = searchInEntity(child) {
                    return found
                }
            }
            
            return nil
        }
        
        return searchInEntity(rootEntity)
    }
    
    // MARK: - Helper Methods
    
    private func createTemporaryURL(from data: Data) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".usdz")
        
        do {
            try data.write(to: tempFile)
            return tempFile
        } catch {
            print("Error creating temporary file: \(error)")
            return nil
        }
    }
}

// MARK: - Supporting Types

public struct SyncData: Codable {
    public let id: String
    public let timestamp: TimeInterval
    public let sequenceNumber: Int
    public let transform: SyncTransform
    public let modelData: Data?
    public let modelURL: URL?
    
    public init(id: String, timestamp: TimeInterval, sequenceNumber: Int, transform: SyncTransform, modelData: Data?, modelURL: URL?) {
        self.id = id
        self.timestamp = timestamp
        self.sequenceNumber = sequenceNumber
        self.transform = transform
        self.modelData = modelData
        self.modelURL = modelURL
    }
}

public struct SyncTransform: Codable {
    public let translation: SIMD3<Float>
    public let rotation: SIMD4<Float>
    public let scale: SIMD3<Float>
    
    public init(from realityKitTransform: RealityKit.Transform) {
        self.translation = realityKitTransform.translation
        self.rotation = SIMD4<Float>(
            realityKitTransform.rotation.vector.x,
            realityKitTransform.rotation.vector.y,
            realityKitTransform.rotation.vector.z,
            realityKitTransform.rotation.vector.w
        )
        self.scale = realityKitTransform.scale
    }
    
    public var realityKitTransform: RealityKit.Transform {
        RealityKit.Transform(
            scale: scale,
            rotation: simd_quatf(vector: rotation),
            translation: translation
        )
    }
}

// MARK: - Entity Extension

public extension Entity {
    /// Configures an entity for model synchronization across devices.
    /// - Parameters:
    ///   - modelURL: The URL of the 3D model to load
    ///   - manager: The MultiDeviceManager instance
    ///   - rootEntity: The root entity to add this entity to
    /// - Returns: The configured entity
    @discardableResult
    func configureModelForSync(modelURL: URL, manager: MultiDeviceManager, rootEntity: Entity) -> Entity {
        // Ensure entity has a name if not set
        if name.isEmpty {
            name = "Model_\(UUID().uuidString)"
        }
        
        // Add sync component
        components.set(SyncComponent(id: name))
        
        // Load and configure model
        if let modelData = try? Data(contentsOf: modelURL) {
            // Add model component
            components.set(SyncModelComponent(modelData: modelData))
            
            // Add to root
            rootEntity.addChild(self)
            
            // Broadcast initial state with model data
            if let entityObservation = manager.entityObservation {
                let transform = SyncTransform(from: transform)
                entityObservation.broadcastTransform(for: self, transform: transform, includeModel: true)
            }
        }
        
        return self
    }
    
    /// Broadcasts a transform update for this entity.
    /// - Parameter manager: The MultiDeviceManager instance
    func broadcastTransformUpdate(manager: MultiDeviceManager) {
        if let entityObservation = manager.entityObservation {
            let transform = SyncTransform(from: transform)
            entityObservation.broadcastTransform(for: self, transform: transform)
        }
    }
} 
