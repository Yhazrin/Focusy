import Foundation
import Network
import FocusCapsuleCore

@MainActor
final class HookServer {
    private let model: AppModel
    private var listener: NWListener?
    private static let maxPayloadSize = 1_048_576

    init(model: AppModel) {
        self.model = model
    }

    func start() {
        unlink(FocusCapsuleSocket.path)
        let oldUmask = umask(0o077)
        let params = NWParameters()
        params.defaultProtocolStack.transportProtocol = NWProtocolTCP.Options()
        params.requiredLocalEndpoint = NWEndpoint.unix(path: FocusCapsuleSocket.path)
        do {
            listener = try NWListener(using: params)
        } catch {
            umask(oldUmask)
            model.lastStatus = "Hook server unavailable"
            return
        }
        listener?.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in self?.handle(connection) }
        }
        listener?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    umask(oldUmask)
                    chmod(FocusCapsuleSocket.path, 0o700)
                    self?.model.lastStatus = "Listening for hooks"
                case .failed:
                    umask(oldUmask)
                    self?.model.lastStatus = "Hook server failed"
                default:
                    break
                }
            }
        }
        listener?.start(queue: .main)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        unlink(FocusCapsuleSocket.path)
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: .main)
        receive(connection, data: Data())
    }

    private func receive(_ connection: NWConnection, data: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, complete, error in
            Task { @MainActor in
                guard let self else { return }
                var next = data
                if let content { next.append(content) }
                if next.count > Self.maxPayloadSize {
                    connection.cancel()
                    return
                }
                if complete || error != nil {
                    self.process(next)
                    connection.cancel()
                } else {
                    self.receive(connection, data: next)
                }
            }
        }
    }

    private func process(_ data: Data) {
        guard let raw = HookEnvelope.decode(data),
              let event = EventNormalizer.normalizeCLIEvent(raw) else { return }
        model.appendEvent(event)
    }
}
