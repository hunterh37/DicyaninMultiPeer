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
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var entityObservation: EntityObservation?
    
    @Published public private(set) var connectedPeers: Set<MCPeerID> = []
    @Published public private(set) var isAdvertising = false
    @Published public private(set) var isBrowsing = false
    @Published public private(set) var isConnected = false
    @Published public private(set) var lastError: Error?
    
    // MARK: - Initialization
    
    public init(displayName: String) {
        self.displayName = displayName
        super.init()
        setupSession()
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
        } catch {
            logger.error("Failed to setup session: \(error.localizedDescription)")
            lastError = error
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
            logger.debug("Sent data to \(session.connectedPeers.count) peers")
        } catch {
            logger.error("Failed to send data: \(error.localizedDescription)")
            lastError = error
        }
    }
}

// MARK: - MCSessionDelegate

extension MultiDeviceManager: MCSessionDelegate {
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        logger.info("Peer \(peerID.displayName) changed state to: \(state.rawValue)")
        logger.info("Current session state before change: \(session.connectedPeers.count) connected peers")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch state {
            case .connected:
                self.connectedPeers.insert(peerID)
                self.isConnected = true
                self.logger.info("Successfully connected to peer: \(peerID.displayName)")
                self.logger.info("Current connected peers count: \(self.connectedPeers.count)")
                self.logger.info("Session connected peers: \(session.connectedPeers.map { $0.displayName })")
            case .connecting:
                self.logger.info("Currently connecting to peer: \(peerID.displayName)")
                self.logger.info("Session state during connection: \(session.connectedPeers.count) connected peers")
            case .notConnected:
                self.connectedPeers.remove(peerID)
                if self.connectedPeers.isEmpty {
                    self.isConnected = false
                    self.logger.info("No peers connected, setting isConnected to false")
                }
                self.logger.info("Disconnected from peer: \(peerID.displayName)")
                self.logger.info("Remaining connected peers count: \(self.connectedPeers.count)")
                self.logger.info("Session connected peers: \(session.connectedPeers.map { $0.displayName })")
            @unknown default:
                self.logger.error("Unknown session state: \(state.rawValue)")
            }
        }
    }
    
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        logger.debug("Received data from peer: \(peerID.displayName)")
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
        logger.info("Current session state: \(session.connectedPeers.count) connected peers")
        
        // Accept the invitation
        invitationHandler(true, session)
        
        // Log the session state after accepting
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.logger.info("Session state after accepting invitation: \(session.connectedPeers.count) connected peers")
            self?.logger.info("Session state: \(session.myPeerID.displayName) is connected: \(session.connectedPeers.contains(peerID))")
        }
    }
    
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        logger.error("Failed to start advertising: \(error.localizedDescription)")
        lastError = error
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
        logger.info("Current session state: \(session.connectedPeers.count) connected peers")
        
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
        
        // Log the session state after sending invitation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.logger.info("Session state after sending invitation: \(session.connectedPeers.count) connected peers")
            self?.logger.info("Session state: \(session.myPeerID.displayName) is connected: \(session.connectedPeers.contains(peerID))")
        }
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        logger.info("Lost peer: \(peerID.displayName)")
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        logger.error("Failed to start browsing: \(error.localizedDescription)")
        lastError = error
    }
} 
