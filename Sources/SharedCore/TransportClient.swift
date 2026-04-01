import Foundation

public enum ConnectionStatus: Equatable, Sendable {
    case idle
    case discovering
    case connecting
    case connected(peerName: String)
    case failed(message: String)
}

public protocol TransportClient: AnyObject {
    var status: ConnectionStatus { get }
    var onStatusChange: (@Sendable (ConnectionStatus) -> Void)? { get set }
    var onEvent: (@Sendable (InputEvent) -> Void)? { get set }

    func connect()
    func disconnect()
    func send(_ event: InputEvent) throws
}

public enum TransportError: LocalizedError {
    case notConnected
    case encodingFailed
    case underlying(Error)

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "現在接続されている相手がいません。"
        case .encodingFailed:
            return "入力イベントのエンコードに失敗しました。"
        case let .underlying(error):
            return error.localizedDescription
        }
    }
}
