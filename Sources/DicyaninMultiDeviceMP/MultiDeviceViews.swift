import SwiftUI
import RealityKit
import MultipeerConnectivity

public struct MultiDeviceConnectionView: View {
    @StateObject private var manager: MultiDeviceManager
    @State private var isShowingSettings = false
    
    public init(displayName: String) {
        _manager = StateObject(wrappedValue: MultiDeviceManager(displayName: displayName))
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Connection Status
            HStack {
                Image(systemName: manager.isConnected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(manager.isConnected ? .green : .gray)
                Text(manager.isConnected ? "Connected" : "Disconnected")
                    .foregroundColor(manager.isConnected ? .green : .gray)
            }
            .font(.headline)
            
            // Connected Peers
            if !manager.connectedPeers.isEmpty {
                VStack(alignment: .leading) {
                    Text("Connected Devices:")
                        .font(.subheadline)
                    ForEach(Array(manager.connectedPeers), id: \.self) { peer in
                        Text(peer.displayName)
                            .font(.caption)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
            }
            
            // Settings Button
            Button(action: { isShowingSettings.toggle() }) {
                Label("Settings", systemImage: "gear")
            }
            .sheet(isPresented: $isShowingSettings) {
                MultiDeviceSettingsView(manager: manager)
            }
        }
        .padding()
    }
}

public struct MultiDeviceSettingsView: View {
    @ObservedObject var manager: MultiDeviceManager
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        NavigationView {
            List {
                Section("Connection") {
                    Toggle("Auto-Connect", isOn: .constant(true))
                        .disabled(true)
                    Toggle("Encryption", isOn: .constant(true))
                        .disabled(true)
                }
                
                Section {
                    if manager.connectedPeers.isEmpty {
                        Text("No devices connected")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(manager.connectedPeers), id: \.self) { peer in
                            HStack {
                                Text(peer.displayName)
                                Spacer()
                                Button("Disconnect") {
                                    // TODO: Implement disconnect
                                }
                                .foregroundColor(.red)
                            }
                        }
                    }
                } header: {
                    Text("Connected Devices")
                }
            }
            .navigationTitle("Multi-Device Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - RealityView Integration
public struct MultiDeviceRealityView: View {
    @StateObject private var manager: MultiDeviceManager
    private let rootEntity: Entity
    @State private var entityCount = 0
    
    public init(displayName: String, rootEntity: Entity) {
        _manager = StateObject(wrappedValue: MultiDeviceManager(displayName: displayName))
        self.rootEntity = rootEntity
    }
    
    public var body: some View {
        ZStack {
            if #available(iOS 18.0, *) {
                RealityView { content in
                    // Create a root entity for synchronization
                    let syncRoot = Entity()
                    syncRoot.name = "SyncRoot"
                    
                    // Add the user's root entity as a child
                    syncRoot.addChild(rootEntity)
                    
                    // Add the sync root to the content
                    content.add(syncRoot)
                    
                    // Start observing the sync root
                    manager.startObserving(rootEntity: syncRoot)
                } update: { content in
                    // This is where we can update the content
                }
            } else {
                // Fallback on earlier versions
            }
            
            VStack {
                Spacer()
                
                // Add Entity Button
                Button(action: {
                    addNewEntity()
                }) {
                    Label("Add Entity", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                }
                .padding(.bottom, 8)
                
                MultiDeviceConnectionView(displayName: manager.displayName)
                    .background(.ultraThinMaterial)
            }
        }
    }
    
    private func addNewEntity() {
        guard let syncRoot = rootEntity.parent else { return }
        
        let newEntity = ModelEntity(mesh: .generateBox(size: 0.3))
        newEntity.name = "Entity_\(entityCount)"
        entityCount += 1
        
        // Position the entity slightly in front of the camera
        newEntity.position = SIMD3(x: 0, y: 0, z: -2)
        
        // Add to the sync root
        syncRoot.addChild(newEntity)
    }
}

// MARK: - Preview Provider
struct MultiDeviceViews_Previews: PreviewProvider {
    static var previews: some View {
        MultiDeviceConnectionView(displayName: "Preview Device")
    }
} 
