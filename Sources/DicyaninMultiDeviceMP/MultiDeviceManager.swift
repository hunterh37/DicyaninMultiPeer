import Foundation
import MultipeerConnectivity
import RealityKit
import Combine
import os.log

public class MultiDeviceManager: NSObject, ObservableObject {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.dicyanin.multidevice", category: "MultiDeviceManager")
    private let serviceType = "dicyanin"
    public let displayName: String
    var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    public var entityObservation: EntityObservation?
    private var connectionTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    
    @Published public private(set) var connectedPeers: Set<MCPeerID> = []
    @Published public private(set) var isAdvertising = false
    @Published public private(set) var isBrowsing = false
    @Published public private(set) var isConnected = false
    @Published public private(set) var lastError: Error?
    @Published public private(set) var connectionStatus: ConnectionStatus = .disconnected
    
    public enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case error
    }
    
    // MARK: - Initialization
    
    public init(displayName: String) {
        self.displayName = displayName
        super.init()
        setupSession()
    }
    
    public static func registerComponents() {
        SyncComponent.registerComponent()
        SyncModelComponent.registerComponent()
    }
    
    public func getSession() -> MCSession? {
        return session
    }
    
    // MARK: - Setup
    
    private func setupSession() {
        do {
            let peerID = MCPeerID(displayName: displayName)
            logger.info("Creating MCPeerID with display name: \(self.displayName)")
            
            session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
            session?.delegate = self
            logger.info("Session setup completed for peer: \(self.displayName)")
            
            // Automatically start advertising and browsing
            startAdvertising()
            startBrowsing()
            
            // Start connection monitoring
            startConnectionMonitoring()
        } catch {
            logger.error("Failed to setup session: \(error.localizedDescription)")
            lastError = error
            connectionStatus = .error
        }
    }
    
    private func startConnectionMonitoring() {
        connectionTimer?.invalidate()
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkConnectionStatus()
        }
    }
    
    private func checkConnectionStatus() {
        guard let session = session else { return }
        
        if session.connectedPeers.isEmpty && isConnected {
            logger.warning("Lost connection to all peers")
            connectionStatus = .disconnected
            isConnected = false
            
            // Attempt to reconnect
            if reconnectAttempts < maxReconnectAttempts {
                reconnectAttempts += 1
                logger.info("Attempting to reconnect (attempt \(self.reconnectAttempts))")
                restartConnection()
            } else {
                logger.error("Max reconnection attempts reached")
                connectionStatus = .error
            }
        }
    }
    
    private func restartConnection() {
        stopAdvertising()
        stopBrowsing()
        
        // Wait a moment before restarting
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startAdvertising()
            self?.startBrowsing()
        }
    }
    
    // MARK: - Public Methods
    
    public func startAdvertising() {
        guard let session = session else {
            logger.error("Cannot start advertising: Session is nil")
            return
        }
        
        do {
            logger.info("Starting advertising with service type: \(self.serviceType)")
            advertiser = MCNearbyServiceAdvertiser(
                peer: session.myPeerID,
                discoveryInfo: nil,
                serviceType: serviceType
            )
            advertiser?.delegate = self
            advertiser?.startAdvertisingPeer()
            isAdvertising = true
            logger.info("Successfully started advertising")
        } catch {
            logger.error("Failed to start advertising: \(error.localizedDescription)")
            lastError = error
            connectionStatus = .error
        }
    }
    
    public func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        isAdvertising = false
        logger.info("Stopped advertising")
    }
    
    public func startBrowsing() {
        guard let session = session else {
            logger.error("Cannot start browsing: Session is nil")
            return
        }
        
        do {
            logger.info("Starting browsing for service type: \(self.serviceType)")
            browser = MCNearbyServiceBrowser(peer: session.myPeerID, serviceType: serviceType)
            browser?.delegate = self
            browser?.startBrowsingForPeers()
            isBrowsing = true
            logger.info("Successfully started browsing")
        } catch {
            logger.error("Failed to start browsing: \(error.localizedDescription)")
            lastError = error
            connectionStatus = .error
        }
    }
    
    public func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
        isBrowsing = false
        logger.info("Stopped browsing")
    }
    
    public func startObserving(rootEntity: Entity) {
        entityObservation = EntityObservation(rootEntity: rootEntity) { [weak self] data in
            self?.sendData(data)
        }
        logger.info("Started observing entity: \(rootEntity.name)")
    }
    
    public func stopObserving() {
        entityObservation = nil
        logger.info("Stopped observing entity")
    }
    
    // MARK: - Private Methods
    
    private func sendData(_ data: Data) {
        guard let session = session, !session.connectedPeers.isEmpty else {
            logger.warning("Cannot send data: No connected peers")
            return
        }
        
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            logger.info("Sent data to \(session.connectedPeers.count) peers")
        } catch {
            logger.error("Failed to send data: \(error.localizedDescription)")
            lastError = error
        }
    }
    
    deinit {
        connectionTimer?.invalidate()
        stopAdvertising()
        stopBrowsing()
    }
}

// MARK: - MCSessionDelegate

extension MultiDeviceManager: MCSessionDelegate {
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        logger.info("Peer \(peerID.displayName) changed state to: \(state.rawValue)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch state {
            case .connected:
                self.connectedPeers.insert(peerID)
                self.isConnected = true
                self.connectionStatus = .connected
                self.reconnectAttempts = 0
                self.logger.info("Successfully connected to peer: \(peerID.displayName)")
            case .connecting:
                self.connectionStatus = .connecting
                self.logger.info("Currently connecting to peer: \(peerID.displayName)")
            case .notConnected:
                self.connectedPeers.remove(peerID)
                if self.connectedPeers.isEmpty {
                    self.isConnected = false
                    self.connectionStatus = .disconnected
                    self.logger.info("No peers connected")
                }
                self.logger.info("Disconnected from peer: \(peerID.displayName)")
            @unknown default:
                self.logger.error("Unknown session state: \(state.rawValue)")
                self.connectionStatus = .error
            }
        }
    }
    
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        logger.info("Received data from peer: \(peerID.displayName)")
        entityObservation?.handleReceivedData(data)
    }
    
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        logger.debug("Received stream from peer: \(peerID.displayName)")
    }
    
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        logger.debug("Started receiving resource from peer: \(peerID.displayName)")
    }
    
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        if let error = error {
            logger.error("Failed to receive resource from peer \(peerID.displayName): \(error.localizedDescription)")
        } else {
            logger.debug("Finished receiving resource from peer: \(peerID.displayName)")
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultiDeviceManager: MCNearbyServiceAdvertiserDelegate {
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        logger.info("Received invitation from peer: \(peerID.displayName)")
        
        guard let session = session else {
            logger.error("Cannot accept invitation: Session is nil")
            invitationHandler(false, nil)
            return
        }
        
        logger.info("Accepting invitation from peer: \(peerID.displayName)")
        invitationHandler(true, session)
    }
    
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        logger.error("Failed to start advertising: \(error.localizedDescription)")
        lastError = error
        connectionStatus = .error
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultiDeviceManager: MCNearbyServiceBrowserDelegate {
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        logger.info("Found peer: \(peerID.displayName)")
        
        guard let session = session else {
            logger.error("Cannot send invitation: Session is nil")
            return
        }
        
        logger.info("Sending invitation to peer: \(peerID.displayName)")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        logger.info("Lost peer: \(peerID.displayName)")
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        logger.error("Failed to start browsing: \(error.localizedDescription)")
        lastError = error
        connectionStatus = .error
    }
} 
