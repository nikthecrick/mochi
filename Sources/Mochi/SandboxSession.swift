import MultipeerConnectivity
import Foundation
import Combine

/// Wire protocol for sandbox messages.
struct SandboxMessage: Codable {
    enum Kind: String, Codable {
        case visit       // casual visit: show as guest, both Mochis stay active
        case transfer    // owner lends their Mochi — freeze theirs, sitter gets active copy
        case returnPet   // sitter sends the Mochi back with updated stats
    }
    var kind: Kind
    var model: PetModel
}

/// Manages peer-to-peer Mochi sharing via MultipeerConnectivity.
/// When the sandbox gadget is active, this advertises the pet's presence and
/// discovers nearby Mochi holders. Dropping your Mochi onto a peer icon sends
/// your PetModel to them; they appear as a guest in your sandbox and vice versa.
final class SandboxSession: NSObject, ObservableObject {
    static let serviceType = "mochi-sandbox"   // ≤15 chars, lowercase + hyphens only

    private let myPeerID: MCPeerID
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser
    private var browser: MCNearbyServiceBrowser
    private weak var engine: PetEngine?

    @Published var nearbyPeers: [MCPeerID] = []
    // Maps a guest's breedName → the peer who transferred them (so we can return them)
    var transferOrigins = [String: MCPeerID]()

    init(engine: PetEngine) {
        self.engine = engine
        let displayName = "Mochi-\(engine.model.breedName ?? "Friend")"
        self.myPeerID = MCPeerID(displayName: displayName)
        self.session = MCSession(peer: myPeerID, securityIdentity: nil,
                                 encryptionPreference: .required)
        self.advertiser = MCNearbyServiceAdvertiser(peer: myPeerID,
                                                   discoveryInfo: nil,
                                                   serviceType: SandboxSession.serviceType)
        self.browser = MCNearbyServiceBrowser(peer: myPeerID,
                                              serviceType: SandboxSession.serviceType)
        super.init()
        self.session.delegate = self
        self.advertiser.delegate = self
        self.browser.delegate = self
    }

    func start() {
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }

    func stop() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
        DispatchQueue.main.async { self.nearbyPeers = [] }
    }

    /// Transfer our Mochi to a peer: freeze ours, send a transfer message.
    func sendMochi(to peer: MCPeerID) {
        guard let engine = engine else { return }
        let msg = SandboxMessage(kind: .transfer, model: engine.model)
        guard let data = try? JSONEncoder().encode(msg) else { return }
        browser.invitePeer(peer, to: session, withContext: data, timeout: 30)
        engine.lendMochi()
    }

    /// Sitter returns the Mochi to its owner (the connected peer who did the transfer).
    func returnMochi(_ model: PetModel, to peer: MCPeerID) {
        let msg = SandboxMessage(kind: .returnPet, model: model)
        guard let data = try? JSONEncoder().encode(msg) else { return }
        try? session.send(data, toPeers: [peer], with: .reliable)
    }
}

// MARK: - MCSessionDelegate

extension SandboxSession: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID,
                 didChange state: MCSessionState) {
        // When a peer disconnects and our Mochi was lent out, unfreeze it
        // (without an updated model — the sitter should use the Return button instead)
        if state == .notConnected {
            DispatchQueue.main.async {
                if self.engine?.model.lentOut == true {
                    self.engine?.returnMochi()
                }
                self.nearbyPeers.removeAll { $0 == peerID }
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data,
                 fromPeer peerID: MCPeerID) {
        guard let msg = try? JSONDecoder().decode(SandboxMessage.self, from: data) else { return }
        DispatchQueue.main.async {
            switch msg.kind {
            case .visit:
                self.engine?.addSandboxGuest(msg.model)
            case .transfer:
                self.engine?.addSandboxGuest(msg.model)
            case .returnPet:
                // Owner gets their Mochi back with updated stats
                self.engine?.returnMochi(updated: msg.model)
                // Remove from our guest list
                self.engine?.sandboxGuests.removeAll { $0.breedName == msg.model.breedName }
                self.transferOrigins.removeValue(forKey: msg.model.breedName ?? "")
            }
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream,
                 withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession,
                 didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession,
                 didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension SandboxSession: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Auto-accept — the payload is JSON pet data, nothing executable
        invitationHandler(true, session)
        guard let context = context,
              let msg = try? JSONDecoder().decode(SandboxMessage.self, from: context) else { return }
        DispatchQueue.main.async {
            self.engine?.addSandboxGuest(msg.model)
            if msg.kind == .transfer, let name = msg.model.breedName {
                self.transferOrigins[name] = peerID
            }
        }
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didNotStartAdvertisingPeer error: Error) {
        print("Mochi sandbox: advertiser error: \(error.localizedDescription)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension SandboxSession: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async {
            if !self.nearbyPeers.contains(peerID) {
                self.nearbyPeers.append(peerID)
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.nearbyPeers.removeAll { $0 == peerID }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser,
                 didNotStartBrowsingForPeers error: Error) {
        print("Mochi sandbox: browser error: \(error.localizedDescription)")
    }
}
