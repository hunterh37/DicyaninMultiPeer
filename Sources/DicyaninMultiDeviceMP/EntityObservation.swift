import Foundation
import RealityKit
import Combine

class EntityObservation {
    private let rootEntity: Entity
    private let onDataReceived: (Data) -> Void
    private var entityObservers: [Entity: AnyCancellable] = [:]
    private var transformUpdateTimer: Timer?
    
    init(rootEntity: Entity, onDataReceived: @escaping (Data) -> Void) {
        self.rootEntity = rootEntity
        self.onDataReceived = onDataReceived
        observeEntity(rootEntity)
        startTransformUpdateTimer()
    }
    
    deinit {
        transformUpdateTimer?.invalidate()
    }
    
    private func startTransformUpdateTimer() {
        transformUpdateTimer?.invalidate()
        transformUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateAndBroadcastTransforms()
        }
    }
    
    private func updateAndBroadcastTransforms() {
        updateEntityTransforms(rootEntity)
    }
    
    private func updateEntityTransforms(_ entity: Entity) {
        broadcastTransform(for: entity, transform: entity.transform)
        
        for child in entity.children {
            updateEntityTransforms(child)
        }
    }
    
    private func observeEntity(_ entity: Entity) {
        // Store reference to entity for periodic updates
        entityObservers[entity] = AnyCancellable {
            // Cleanup if needed
        }
        
        // Observe children
        for child in entity.children {
            observeEntity(child)
        }
    }
    
    private func broadcastTransform(for entity: Entity, transform: Transform) {
        let transformData = TransformData(
            entityName: entity.name,
            position: transform.translation,
            rotation: transform.rotation,
            scale: transform.scale
        )
        
        do {
            let data = try JSONEncoder().encode(transformData)
            onDataReceived(data)
        } catch {
            print("Error broadcasting transform: \(error)")
        }
    }
    
    func handleReceivedData(_ data: Data) {
        do {
            let transformData = try JSONDecoder().decode(TransformData.self, from: data)
            updateEntityTransform(transformData)
        } catch {
            print("Error receiving transform data: \(error)")
        }
    }
    
    private func updateEntityTransform(_ data: TransformData) {
        // Find the entity by name in the hierarchy
        if let entity = findEntity(named: data.entityName, in: rootEntity) {
            DispatchQueue.main.async {
                entity.transform = Transform(
                    scale: data.scale,
                    rotation: data.rotation.quaternion,
                    translation: data.position
                )
            }
        }
    }
    
    private func findEntity(named name: String, in entity: Entity) -> Entity? {
        if entity.name == name {
            return entity
        }
        
        for child in entity.children {
            if let found = findEntity(named: name, in: child) {
                return found
            }
        }
        
        return nil
    }
}

// MARK: - Supporting Types
private struct CodableQuaternion: Codable {
    let x: Float
    let y: Float
    let z: Float
    let w: Float
    
    init(quaternion: simd_quatf) {
        self.x = quaternion.vector.x
        self.y = quaternion.vector.y
        self.z = quaternion.vector.z
        self.w = quaternion.vector.w
    }
    
    var quaternion: simd_quatf {
        simd_quatf(vector: SIMD4<Float>(x, y, z, w))
    }
}

private struct TransformData: Codable {
    let entityName: String
    let position: SIMD3<Float>
    let rotation: CodableQuaternion
    let scale: SIMD3<Float>
    
    init(entityName: String, position: SIMD3<Float>, rotation: simd_quatf, scale: SIMD3<Float>) {
        self.entityName = entityName
        self.position = position
        self.rotation = CodableQuaternion(quaternion: rotation)
        self.scale = scale
    }
} 