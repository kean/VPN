// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation
import Combine
import NetworkExtension
import UIKit

final class VPNConfigurationService: ObservableObject {
    @Published private(set) var isStarted = false

    /// If not nil, the tunnel is displayed.
    @Published private(set) var tunnel: NETunnelProviderManager?

    static let shared = VPNConfigurationService()

    private var observer: AnyObject?

    private init() {
        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
        }
    }

    private func refresh() {
        refresh { _ in }
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

        // WARNING: This must match the bundle identifier of the app extension
        // containing packet tunnel provider.
        proto.providerBundleIdentifier = "com.github.kean.vpn-client.vpn-tunnel"

        // WARNING: This must send the actual VPN server address, for the demo
        // purposes, I'm passing the address of the server in my local network.
        // The address is going to be different in your network.
        proto.serverAddress = "192.168.0.13:9999"

        proto.username = "kean"
        proto.passwordReference = {
            let keychain = Keychain(group: "group.com.github.kean.vpn-client")
            keychain.set(password: "123456", for: "kean")
            return keychain.passwordReference(for: "kean")
        }()

        manager.protocolConfiguration = proto

        // Uncomment this to configure on-demand rules to make sure the tunnel
        // starts automatically when needed.
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
