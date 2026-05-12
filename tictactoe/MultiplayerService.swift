//
//  MultiplayerService.swift
//  tictactoe
//
//  Created by Axel Behm on 12.05.26.
//

import Foundation
import Combine
import MultipeerConnectivity

struct MultiplayerMessage: Codable {
    enum Kind: String, Codable {
        case move
        case reset
    }

    let kind: Kind
    let index: Int?
    let player: String?
    let variant: String
}

final class MultiplayerService: NSObject, ObservableObject {
    private static let serviceType = "tictactoe"

    @Published private(set) var isHosting = false
    @Published private(set) var isSearching = false
    @Published private(set) var isConnected = false
    @Published private(set) var connectedPeerName: String?
    @Published var receivedMessage: MultiplayerMessage?

    private let peerID = MCPeerID(displayName: ProcessInfo.processInfo.hostName)
    private lazy var session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    var connectionText: String {
        if let connectedPeerName {
            return "Verbunden mit \(connectedPeerName)"
        }

        if isHosting {
            return "Warte auf zweites iPhone ..."
        }

        if isSearching {
            return "Suche ein Spiel in der Nähe ..."
        }

        return "Noch nicht verbunden."
    }

    override init() {
        super.init()
        session.delegate = self
    }

    func startHosting() {
        disconnect()

        isHosting = true
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: Self.serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    func startSearching() {
        disconnect()

        isSearching = true
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    func disconnect() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil

        browser?.stopBrowsingForPeers()
        browser = nil

        session.disconnect()
        isHosting = false
        isSearching = false
        isConnected = false
        connectedPeerName = nil
    }

    func send(_ message: MultiplayerMessage) {
        guard !session.connectedPeers.isEmpty,
              let data = try? JSONEncoder().encode(message) else {
            return
        }

        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }
}

extension MultiplayerService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        Task { @MainActor in
            invitationHandler(true, self.session)
        }
    }
}

extension MultiplayerService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            guard self.session.connectedPeers.isEmpty else {
                return
            }

            browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 20)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    }
}

extension MultiplayerService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            self.isConnected = state == .connected
            self.connectedPeerName = state == .connected ? peerID.displayName : nil

            if state == .connected {
                self.isSearching = false
                self.browser?.stopBrowsingForPeers()
                self.browser = nil
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.receivedMessage = try? JSONDecoder().decode(MultiplayerMessage.self, from: data)
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
    }

    nonisolated func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {
    }

    nonisolated func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {
    }
}
