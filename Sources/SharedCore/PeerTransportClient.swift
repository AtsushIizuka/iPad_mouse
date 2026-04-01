import Foundation
@preconcurrency import MultipeerConnectivity
#if canImport(UIKit)
import UIKit
#endif

public enum TransportRole: String, Sendable {
    case controller
    case host
}

public final class PeerTransportClient: NSObject, TransportClient, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    public static let serviceType = "ipadmousepad"

    public var onStatusChange: (@Sendable (ConnectionStatus) -> Void)?
    public var onEvent: (@Sendable (InputEvent) -> Void)?
    public private(set) var status: ConnectionStatus = .idle {
        didSet {
            guard oldValue != status else { return }
            let onStatusChange = onStatusChange
            let status = status
            DispatchQueue.main.async {
                onStatusChange?(status)
            }
        }
    }

    private let role: TransportRole
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let peerID: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var pendingPeer: MCPeerID?

    public init(role: TransportRole, displayName: String? = nil) {
        self.role = role
        self.peerID = MCPeerID(displayName: displayName ?? Self.defaultPeerName(for: role))
        self.session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        session.delegate = self
    }

    public func connect() {
        switch status {
        case .idle, .failed:
            break
        case .discovering, .connecting, .connected:
            restartDiscoveryIfNeeded()
            return
        }

        switch role {
        case .host:
            advertiser?.stopAdvertisingPeer()
            advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: Self.serviceType)
            advertiser?.delegate = self
            advertiser?.startAdvertisingPeer()
            status = .discovering
        case .controller:
            browser?.stopBrowsingForPeers()
            browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
            browser?.delegate = self
            browser?.startBrowsingForPeers()
            status = .discovering
        }
    }

    public func disconnect() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        pendingPeer = nil
        session.disconnect()
        status = .idle
    }

    public func send(_ event: InputEvent) throws {
        guard !session.connectedPeers.isEmpty else {
            throw TransportError.notConnected
        }

        do {
            let data = try encoder.encode(event)
            try session.send(data, toPeers: session.connectedPeers, with: deliveryMode(for: event))
        } catch {
            throw TransportError.underlying(error)
        }
    }

    private func restartDiscoveryIfNeeded() {
        switch role {
        case .host:
            if advertiser == nil {
                connect()
            }
        case .controller:
            if browser == nil {
                connect()
            }
        }
    }

    private func reconnectIfNeeded() {
        switch role {
        case .controller:
            browser?.startBrowsingForPeers()
        case .host:
            advertiser?.startAdvertisingPeer()
        }
        status = .discovering
    }

    private func notifyReceived(_ event: InputEvent) {
        let onEvent = onEvent
        DispatchQueue.main.async {
            onEvent?(event)
        }
    }

    private func deliveryMode(for event: InputEvent) -> MCSessionSendDataMode {
        switch event {
        case .pointerMove, .scroll:
            return .unreliable
        case .click, .button, .gesture:
            return .reliable
        }
    }

    private func failureMessage(for error: any Error) -> String {
        let nsError = error as NSError

        if nsError.domain == NetService.errorDomain, nsError.code == -72008 {
            switch role {
            case .controller:
                return "iPad 側でローカルネットワークが許可されていません。設定で PadTrack のローカルネットワークをオンにしてから、再接続を押してください。"
            case .host:
                return "Mac 側でローカルネットワークが許可されていません。システム設定で MacPointerHost のローカルネットワークをオンにしてから、再接続を押してください。"
            }
        }

        return nsError.localizedDescription
    }

    private static func defaultPeerName(for role: TransportRole) -> String {
        switch role {
        case .host:
            return "Mac Pointer Host"
        case .controller:
            return "PadTrack コントローラ"
        }
    }
}

extension PeerTransportClient {
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .notConnected:
            pendingPeer = nil
            reconnectIfNeeded()
        case .connecting:
            status = .connecting
        case .connected:
            browser?.stopBrowsingForPeers()
            pendingPeer = nil
            status = .connected(peerName: peerID.displayName)
        @unknown default:
            status = .failed(message: "不明な MultipeerConnectivity 状態です。")
        }
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let event = try decoder.decode(InputEvent.self, from: data)
            notifyReceived(event)
        } catch {
            status = .failed(message: "\(peerID.displayName) から受信した入力を読み取れませんでした。")
        }
    }

    public func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    public func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    public func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: (any Error)?
    ) {}
}

extension PeerTransportClient {
    public func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        let shouldAccept = session.connectedPeers.isEmpty && pendingPeer == nil
        if shouldAccept {
            pendingPeer = peerID
            status = .connecting
        }
        invitationHandler(shouldAccept, session)
    }

    public func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didNotStartAdvertisingPeer error: any Error
    ) {
        status = .failed(message: failureMessage(for: error))
    }
}

extension PeerTransportClient {
    public func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        guard session.connectedPeers.isEmpty, pendingPeer == nil else { return }
        pendingPeer = peerID
        status = .connecting
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        if pendingPeer == peerID {
            pendingPeer = nil
            status = .discovering
        }
    }

    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: any Error) {
        status = .failed(message: failureMessage(for: error))
    }
}
