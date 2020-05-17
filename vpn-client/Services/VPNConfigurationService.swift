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

    private var observer: AnyObject?

    private init() {
        
    }

    func refresh(_ completion: @escaping (Result<Void, Error>) -> Void) {
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

        let proto = NETunnelProviderProtocol()
        // TODO: Set the bundle identifier of the Packet Tunnel Provider
        // App Extension
        proto.providerBundleIdentifier = "com.github.kean.vpn-client.vpn-tunnel"
        // TODO: Set an actual VPN server address, in the sample project
        // we are going to deploy the service locally.
        proto.serverAddress = "127.0.0.1:4009"
        proto.providerConfiguration = ["user":"kean"]

        manager.protocolConfiguration = proto

        // Make sure that VPN connects automatically.
        #warning("TEMP:")
//        let onDemandRule = NEOnDemandRuleConnect()
//        onDemandRule.interfaceTypeMatch = .any
//        manager.isOnDemandEnabled = true
//        manager.onDemandRules = [onDemandRule]

        // Enable the manager bu default.
        manager.isEnabled = true

        return manager
    }

    private func statusUpdated() {

    }
    
    func removeProfile(_ completion: @escaping (Result<Void, Error>) -> Void) {
        assert(tunnel != nil, "Tunnel is missing")
        tunnel?.removeFromPreferences { error in
            if let error = error {
                return completion(.failure(error))
            }
            self.tunnel = nil
            completion(.success(()))
        }
    }
}

// MARK: - Extensions

/// Make NEVPNStatus convertible to a string
extension NEVPNStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .invalid: return "Invalid"
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .disconnecting: return "Disconnecting"
        case .reasserting: return "Reconnecting"
        @unknown default: return "Unknown"
        }
    }
}
