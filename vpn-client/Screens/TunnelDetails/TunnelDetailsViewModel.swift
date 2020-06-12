// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Combine
import NetworkExtension

final class TunnelViewModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""
    @Published var server = ""

    @Published var isEnabled = false
    @Published var isStarted = false

    @Published private(set) var status: String = "Unknown"

    @Published var isLoading = false
    @Published var isShowingError = false
    @Published private(set) var errorTitle = ""
    @Published private(set) var errorMessage = ""

    private let service: VPNConfigurationService
    private let tunnel: NETunnelProviderManager

    private var observers = [AnyObject]()
    private var bag = [AnyCancellable]()

    init(service: VPNConfigurationService = .shared, tunnel: NETunnelProviderManager) {
        self.service = service
        self.tunnel = tunnel

        self.refresh()

        observers.append(NotificationCenter.default
            .addObserver(forName: .NEVPNStatusDidChange, object: tunnel.connection, queue: .main) { [weak self] _ in
                self?.refresh()
        })

        observers.append(NotificationCenter.default
            .addObserver(forName: .NEVPNConfigurationChange, object: tunnel, queue: .main) { [weak self] _ in
                self?.refresh()
        })

        $isEnabled.sink { [weak self] in
            self?.setEnabled($0)
        }.store(in: &bag)
    }

    private func refresh() {
        self.status = tunnel.connection.status.description
        let username = tunnel.protocolConfiguration?.username ?? ""
        self.username = username
        self.password = tunnel.protocolConfiguration?.passwordReference.flatMap {
            Keychain.password(for: username, reference: $0)
        } ?? ""
        self.server = tunnel.protocolConfiguration?.serverAddress ?? ""
        self.isEnabled = tunnel.isEnabled
        self.isStarted = tunnel.connection.status != .disconnected && tunnel.connection.status != .invalid
    }

    private func setEnabled(_ isEnabled: Bool) {
        guard isEnabled != tunnel.isEnabled else { return }
        tunnel.isEnabled = isEnabled
        saveToPreferences()
    }

    func buttonStartTapped() {
        do {
            try tunnel.connection.startVPNTunnel(options: [:] as [String : NSObject])
        } catch {
            self.showError(title: "Failed to start VPN tunnel", message: error.localizedDescription)
        }
    }

    func buttonStopTapped() {
        tunnel.connection.stopVPNTunnel()
    }

    func buttonRemoveProfileTapped() {
        isLoading = true

        service.removeProfile { [weak self] in
            guard let self = self else { return }
            self.isLoading = false
            switch $0 {
            case .success:
            break // Do nothing, router will show what's next
            case let .failure(error):
                self.showError(title: "Failed to install a profile", message: error.localizedDescription)
            }
        }
    }

    private func saveToPreferences() {
        isLoading = true
        tunnel.saveToPreferences { [weak self] error in
            guard let self = self else { return }
            self.isLoading = false
            if let error = error {
                self.showError(title: "Failed to update VPN configuration", message: error.localizedDescription)
                self.errorMessage = error.localizedDescription
                return
            }
        }
    }

    private func showError(title: String, message: String) {
        self.errorTitle = title
        self.errorMessage = message
        self.isShowingError = true
    }

    func buttonSaveTapped() {
        let proto = tunnel.protocolConfiguration as! NETunnelProviderProtocol
        proto.username = self.username
        proto.passwordReference = {
            let keychain = Keychain(group: "group.com.github.kean.vpn-client")
            keychain.set(password: self.password, for: username)
            return keychain.passwordReference(for: username)
        }()
        proto.serverAddress = server

        tunnel.protocolConfiguration = proto

        saveToPreferences()
    }

    private func sayHelloToTunnel() {
        // Send a simple IPC message to the provider, handle the response.
        guard let session = tunnel.connection as? NETunnelProviderSession,
            let message = "Hello Provider".data(using: String.Encoding.utf8), tunnel.connection.status != .invalid else {
                return
        }

        do {
            try session.sendProviderMessage(message) { response in
                if response != nil {
                    let responseString = NSString(data: response!, encoding: String.Encoding.utf8.rawValue)
                    NSLog("Received response from the provider: \(String(describing: responseString))")
                } else {
                    NSLog("Got a nil response from the provider")
                }
            }
        } catch {
            NSLog("Failed to send a message to the provider")
        }
    }
}
