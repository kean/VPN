// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import NetworkExtension
import os.log
import VPNProtocol
import CryptoKit

class PacketTunnelProvider: NEPacketTunnelProvider {

    private var udpSession: NWUDPSession!
    private var key: SymmetricKey!
    private var observer: AnyObject?
    private let queue = DispatchQueue(label: "test")
    private var pendingCompletion: ((Error?) -> Void)?
    private let log = OSLog(subsystem: "vpn-tunnel", category: "default")

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("Starting tunnel", log: log)

        self.pendingCompletion = completionHandler

        /// Get a "pre-shared" symmetric key.
        /// WARNING: Don't do this in production.
        self.key = Cipher.key

        self.startUDPSession()

        #warning("TODO: complete setup")
//        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "192.168.0.14")  
//        setTunnelNetworkSettings(settings) { error in
//            completionHandler(error)
//        }
    }

    private func startUDPSession() {
        let endpoint = NWHostEndpoint(hostname: "192.168.0.13", port: "9999")
        self.udpSession = createUDPSession(to: endpoint, from: nil)
        self.observer = udpSession.observe(\.state, options: [.new]) { [weak self] session, _ in
            guard let self = self else { return }
            self.queue.async {
                self.udpSession(session, didUpdateState: session.state)
            }
        }
    }

    #warning("TODO: pass server address from the app")
    private func udpSession(_ session: NWUDPSession, didUpdateState state: NWUDPSessionState) {
        os_log("#%{PUBLIC}@ did update state: %{PUBLIC}@", log: log, session, "\(state)")

        guard pendingCompletion != nil else { return }
        switch state {
        case .ready:
            session.setReadHandler({ [weak self] datagrams, error in
                guard let self = self else { return }
                self.queue.async {
                    if let datagrams = datagrams {
                        for datagram in datagrams {
                            try? self.didReceiveDatagram(datagram: datagram)
                        }
                    } else {
                        // TODO: Handle error
                    }
                }
            }, maxDatagrams: Int.max)

            #warning("TODO: pass password via keychain")
            do {
                try self.authenticate(login: "kean", password: "123")
            } catch {
                os_log(.fault, log: log, "Failed to authenticate")
            }
        case .failed:
            pendingCompletion?(PacketTunnelError.failedToEstablishConnection)
            pendingCompletion = nil
        default:
            break
        }
    }

    private func didReceiveDatagram(datagram: Data) throws {
        let code = try PacketCode(datagram: datagram)
        switch code {
        case .serverAuthResponse:
            let response = try MessageDecoder.decode(Body.ServerAuthResponse.self, datagram: datagram, key: key)
            if response.isOK {
                self.didSetupTunnel(address: response.address)
            }
        case .data:
            #warning("TODO:")
//            let packet = // Decrypt `datagram`
//            let protocolNumber = IPHeader.protocolNumber(inPacket: packet)
//            self.packetFlow.writePackets([packet], withProtocols: [protocolNumber])
        default:
            break
        }
    }

    private func didSetupTunnel(address: String) {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: address)
        // Configure DNS/split-tunnel/etc settings if needed
        setTunnelNetworkSettings(settings) { error in
            self.pendingCompletion?(nil)
            self.pendingCompletion = nil
        }
    }

    private func authenticate(login: String, password: String) throws {
        let datagram = try MessageEncoder.encode(
            header: Header(code: .clientAuthRequest),
            body: Body.ClientAuthRequest(login: login, password: password),
            key: key
        )

        udpSession.writeDatagram(datagram) { error in
            // Handle error
        }
    }

    private func startTunnel() throws {


        #warning("TODO: read login/password")
    }

    private func didStartTunnel() {
        readPackets()
    }

    private func readPackets() {
        packetFlow.readPacketObjects { packets in
            #warning("TODO:")
//            let datagrams = packets.map {
//                // Encrypt data
//            }
//
//            self.session.writeMultipleDatagrams(datagrams) { error in
//                // Handle errors
//            }

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

private enum PacketTunnelError: Swift.Error {
    case failedToEstablishConnection
}
