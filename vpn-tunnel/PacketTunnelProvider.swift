// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import NetworkExtension
import os.log
import VPNProtocol

class PacketTunnelProvider: NEPacketTunnelProvider {

    private var session: NWUDPSession!
    private var observer: AnyObject?
    private let queue = DispatchQueue(label: "test")
    private var pendingCompletion: ((Error?) -> Void)?
    private let log = OSLog(subsystem: "vpn-tunnel", category: "default")

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("Starting tunnel", log: log)

        self.pendingCompletion = completionHandler

        #warning("TODO: complete setup")
//        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "192.168.0.14")  
//        setTunnelNetworkSettings(settings) { error in
//            completionHandler(error)
//        }
    }

    private func startUDPSession() {
        let endpoint = NWHostEndpoint(hostname: "192.168.0.13", port: "9999")
        self.session = createUDPSession(to: endpoint, from: nil)
        self.observer = session.observe(\.state, options: [.new]) { [weak self] session, _ in
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
            session.setReadHandler({ (data, error) in
                print("received: ", data, error)
            }, maxDatagrams: Int.max)

            #warning("TODO: pass password via keychain")
            self.authenticate(login: "kean", password: "123")
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
            let response = try Packets.ServerAuthResponse(datagram: datagram)
            if response.isOK {
                self.didSetupTunnel(address: response.address)
            }
        case .data:
            let packet = // Decrypt `datagram`
            let protocolNumber = IPHeader.protocolNumber(inPacket: packet)
            self.packetFlow.writePackets([packet], withProtocols: [protocolNumber])
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

    private func authenticate(login: String, password: String) {
        let packet = Packets.ClientAuthRequest(login: login, password: password)
        #warning("TODO: handle errors")
        session!.writeDatagram(try! packet.datagram()) { error in
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
            let datagrams = packets.map {
                // Encrypt data
            }

            self.session.writeMultipleDatagrams(datagrams) { error in
                // Handle errors
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

private enum PacketTunnelError: Swift.Error {
    case failedToEstablishConnection
}
