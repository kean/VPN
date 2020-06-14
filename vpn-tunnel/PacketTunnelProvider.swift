// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import NetworkExtension
import BestVPN
import CryptoKit
import os.log

class PacketTunnelProvider: NEPacketTunnelProvider {

    private var configuration: Configuration!
    private var udpSession: NWUDPSession!
    private var key: SymmetricKey!
    private var observer: AnyObject?
    #warning("TODO: do we need this queue?")
    private let queue = DispatchQueue(label: "com.github.packet-tunnel-provider")
    private let log = OSLog(subsystem: "vpn-tunnel-ptp", category: "default")
    private var pendingCompletion: ((Error?) -> Void)?
    private weak var timeoutTimer: Timer?

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log(.default, log: log, "Starting tunnel, options: %{private}@", "\(String(describing: options))")

        do {
            guard let proto = protocolConfiguration as? NETunnelProviderProtocol else {
                throw NEVPNError(.configurationInvalid)
            }
            self.configuration = try Configuration(proto: proto)
        } catch {
            os_log(.error, log: log, "Failed to read the configuration", error.localizedDescription)
            completionHandler(error)
        }

        os_log(.default, log: log, "Read configuration %{private}@", "\(String(describing: configuration))")

        // "Get" a pre-shared symmetric key.
        //
        // WARNING: Don't do this in production! This code uses the same key
        // every time for simplicity. In practice, you are going to want to
        // either pre-share it properly, or implement proper TLS handshake.
        self.key = Cipher.key

        // Remember the completion handler so that we could call it when the
        // the connection with the server is established.
        //
        // When the Packet Tunnel Provider executes the completionHandler block
        // with a nil error parameter, it signals to the system that it is ready
        // to begin handling network data. Therefore, the Packet Tunnel Provider
        // should call `setTunnelNetworkSettings(_:completionHandler:)` and wait
        // for it to complete before executing the completionHandler block.
        //
        // The domain and code of the NSError object passed to the completionHandler
        // block are defined by the Packet Tunnel Provider (`NEVPNError`).
        self.pendingCompletion = completionHandler

        self.startTunnel()
    }

    private func startTunnel() {
        self.startUDPSession()

        self.timeoutTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            self.pendingCompletion?(NEVPNError(.connectionFailed))
            self.pendingCompletion = nil
        }
    }

    private func startUDPSession() {
        os_log(.default, log: log, "Starting UDP session, hostname: %{public}@, port: %{public}@", configuration.hostname, configuration.port)

        let endpoint = NWHostEndpoint(hostname: configuration.hostname, port: configuration.port)
        self.udpSession = createUDPSession(to: endpoint, from: nil)
        self.observer = udpSession.observe(\.state, options: [.new]) { [weak self] session, _ in
            guard let self = self else { return }
            os_log(.default, log: self.log, "Session did update state: %{public}@", session.state.description)
            self.queue.async {
                self.udpSession(session, didUpdateState: session.state)
            }
        }
    }

    private func udpSession(_ session: NWUDPSession, didUpdateState state: NWUDPSessionState) {
        switch state {
        case .ready:
            guard pendingCompletion != nil else { return }

            session.setReadHandler({ [weak self] datagrams, error in
                guard let self = self else { return }
                self.queue.async {
                    self.didReceiveDatagrams(datagrams: datagrams ?? [], error: error)
                }
            }, maxDatagrams: Int.max)

            do {
                try self.authenticate(username: configuration.username, password: configuration.password)
            } catch {
                // TODO: handle errors
                os_log(.default, log: self.log, "Did fail to authenticate: %{public}@", "\(error)")
            }
        case .failed:
            guard pendingCompletion != nil else { return }
            pendingCompletion?(NEVPNError(.connectionFailed))
            pendingCompletion = nil
        default:
            break
        }
    }

    private func didReceiveDatagrams(datagrams: [Data], error: Error?) {
        for datagram in datagrams {
            do {
                try self.didReceiveDatagram(datagram: datagram)
            } catch {
                // TODO: handle error
                os_log(.default, log: self.log, "UDP session read handler error: %{public}@", "\(error)")
            }
        }
        if let error = error {
            // TODO: handle error
            os_log(.default, log: self.log, "UDP session read handler error: %{public}@", "\(error)")
        }
    }

    private func didReceiveDatagram(datagram: Data) throws {
        let code = try PacketCode(datagram: datagram)

        os_log(.default, log: self.log, "Did receive datagram with code: %{public}@", "\(code)")

        switch code {
        case .serverAuthResponse:
            let response = try MessageDecoder.decode(Body.ServerAuthResponse.self, datagram: datagram, key: key)
            os_log(.default, log: self.log, "Did receive auth response: %{private}@", "\(response)")
            if response.isOK {
                // TODO: In reality, you would pass a resolved IP address, in our
                // case we already provide an IP address in the configurtaion
                self.didSetupTunnel(address: configuration.hostname)
            } else {
                // TODO: Handle error
            }
            self.timeoutTimer?.invalidate()
        case .data:
            let data = try MessageDecoder.decode(Data.self, datagram: datagram, key: key)
            let proto = protocolNumber(for: data)
            self.packetFlow.writePackets([data], withProtocols: [proto])
        default:
            break
        }
    }

    private func didSetupTunnel(address: String) {
        os_log(.default, log: self.log, "Did setup tunnel with address: %{public}@", "\(address)")

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: address)
        // TODO: Configure DNS/split-tunnel/etc settings if needed

        setTunnelNetworkSettings(settings) { error in
            os_log(.default, log: self.log, "Did setup tunnel settings: %{public}@, error: %{public}@", "\(settings)", "\(String(describing: error))")

            self.pendingCompletion?(error)
            self.pendingCompletion = nil

            self.didStartTunnel()
        }
    }

    private func authenticate(username: String, password: String) throws {
        let datagram = try MessageEncoder.encode(
            header: Header(code: .clientAuthRequest),
            body: Body.ClientAuthRequest(login: username, password: password),
            key: key
        )

        udpSession.writeDatagram(datagram) { error in
            if let error = error {
                // TODO: Handle errors
                os_log(.default, log: self.log, "Failed to write auth request datagram, error: %{public}@", "\(error)")
            }
        }
    }

    private func didStartTunnel() {
        readPackets()
    }

    private func readPackets() {
        packetFlow.readPacketObjects { packets in
            do {
                let datagrams = try packets.map {
                    try MessageEncoder.encode(
                        header: Header(code: .data),
                        body: $0.data,
                        key: key
                    )
                }
                self.session.writeMultipleDatagrams(datagrams) { error in
                    // TODO: Handle errors
                }
            } catch {
                // TODO: Handle errors
            }

            self.readPackets()
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
    }
}

private struct Configuration {
    let username: String
    let password: String
    let hostname: String
    let port: String

    init(proto: NETunnelProviderProtocol) throws {
        guard let fullServerAddress = proto.serverAddress else {
            throw NEVPNError(.configurationInvalid)
        }
        let serverAddressParts = fullServerAddress.split(separator: ":")
        guard serverAddressParts.count == 2 else {
            throw NEVPNError(.configurationInvalid)
        }

        self.hostname = String(serverAddressParts[0])
        self.port = String(serverAddressParts[1])

        guard let username = proto.username else {
            throw NEVPNError(.configurationInvalid)
        }
        self.username = username

        guard let password = proto.passwordReference.flatMap({
            Keychain.password(for: username, reference: $0)
        }) else {
            throw NEVPNError(.configurationInvalid)
        }
        self.password = password
    }
}

extension NWUDPSessionState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .cancelled: return ".cancelled"
        case .failed: return ".failed"
        case .invalid: return ".invalid"
        case .preparing: return ".preparing"
        case .ready: return ".ready"
        case .waiting: return ".waiting"
        @unknown default: return "unknown"
        }
    }
}

private func protocolNumber(for packet: Data) -> NSNumber {
    guard !packet.isEmpty else {
        return AF_INET as NSNumber
    }

    // 'packet' contains the decrypted incoming IP packet data

    // The first 4 bits identify the IP version
    let ipVersion = (packet[0] & 0xf0) >> 4
    return (ipVersion == 6) ? AF_INET6 as NSNumber : AF_INET as NSNumber
}
