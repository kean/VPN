// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation
import Combine
import NetworkExtension

final class VPNConfigurationService: ObservableObject {
    @Published private(set) var isStarted = false

    /// If not nil, the tunnel is displayed.
    @Published private(set) var tunnel: NETunnelProviderManager?

    static let shared = VPNConfigurationService()

    private init() {
        
    }

    func refresh(_ completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {

        // Read all of the VPN configurations created by the app that have
        // previously been saved to the Network Extension preferences.
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }

            // There is only one VPN configuration the app provides
            self.tunnel = managers?.first
            if let error = error {
                completion(.failure(error))
            } else {
                self.isStarted = true
                completion(.success(()))
            }
        }
        }
    }

    func startTunnel() throws {
        assert(tunnel != nil, "Tunnel is missing")
        try tunnel?.connection.startVPNTunnel()
    }

    func installProfile(_ completion: @escaping (Result<Void, Error>) -> Void) {
        let tunnel = makeManager()
        tunnel.saveToPreferences { [weak self] error in
            if let error = error {
                return completion(.failure(error))
            }

            // See https://forums.developer.apple.com/thread/25928
            tunnel.loadFromPreferences { [weak self] error in
                self?.tunnel = tunnel
                completion(.success(()))
            }
        }
    }

    private func makeManager() -> NETunnelProviderManager {
        let manager = NETunnelProviderManager()

        manager.localizedDescription = "BestVPN"

        manager.protocolConfiguration = {
            let configuration = NETunnelProviderProtocol()
            configuration.providerBundleIdentifier = "com.github.kean.vpn-client.vpn-tunnel"
            #warning("TODO: configure with your VPN address")
            configuration.serverAddress = "127.0.0.1/4009"
            return configuration
        }()

        // Make sure that VPN connects automatically.
        manager.isOnDemandEnabled = true
        let rule = NEOnDemandRuleConnect()
        rule.interfaceTypeMatch = .any
        manager.onDemandRules = [rule]

        manager.isEnabled = true

        return manager
    }
}
