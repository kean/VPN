// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {

    private var session: NWUDPSession?
    private var observer: AnyObject?
    private let queue = DispatchQueue(label: "test")

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        NSLog("Starting tunnel with options: \(options ?? [:])")
        // Add code here to start the process of connecting the tunnel.

        #warning("TEMP:")

        let endpoint = NWHostEndpoint(hostname: "192.168.0.13", port: "9999")
        let session = createUDPSession(to: endpoint, from: nil)
        self.session = session
        observer = session.observe(\.state, options: [.new]) { (session, change) in
            self.queue.async {
                NSLog("state updated: \(change)")
                NSLog("state: \(session.state)")

                if session.state == .ready {
                    session.setReadHandler({ (data, error) in
                        print("received: ", data, error)
                    }, maxDatagrams: Int.max)
                    let data = "hello".data(using: .utf8)!
                    session.writeDatagram(data) { (error) in
                        print("sent: ", error)
                    }
                }
            }
        }

//        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "192.168.0.14")  
//        setTunnelNetworkSettings(settings) { error in
//            completionHandler(error)
//        }
    }

    private func startTunnel() throws {
        guard let tunnelProtocol = protocolConfiguration as? NETunnelProviderProtocol else {
            throw TunnelError.parameterMissing("protocolConfiguration")
        }
        guard let serverAddress = tunnelProtocol.serverAddress else {
            throw TunnelError.parameterMissing("protocolConfiguration.serverAddress")
        }
        guard let providerConfiguration = tunnelProtocol.providerConfiguration else {
            throw TunnelError.parameterMissing("protocolConfiguration.providerConfiguration")
        }

        #warning("TODO: read login/password")
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
