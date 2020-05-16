// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Combine
import NetworkExtension

struct TunnelStatusView: View {
    @ObservedObject var model: TunnelViewModel

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Status: ") + Text(model.status).bold()
                }
                Section {
                    Toggle(isOn: $model.isEnabled, label: { Text("Enabled") })
                    if model.isEnabled {
                        if model.isStarted {
                            Button(action: model.buttonStopTapped) { Text("Stop") }
                                .foregroundColor(Color.orange)
                        } else {
                            Button(action: model.buttonStartTapped) { Text("Start") }
                                .foregroundColor(Color.blue)
                        }
                    }
                }
                Section {
                    ButtonRemoveProfile(model: model)
                }
            }
            .disabled(model.isLoading)
            .alert(isPresented: $model.isShowingError) {
                Alert(
                    title: Text(self.model.errorTitle),
                    message: Text(self.model.errorMessage),
                    dismissButton: .cancel()
                )
            }
            .navigationBarItems(trailing:
                Spinner(isAnimating: $model.isLoading, color: .label, style: .medium)
            )
            .navigationBarTitle("VPN Status")
        }
    }
}

private struct ButtonRemoveProfile: View {
    let model: TunnelViewModel

    @State private var isConfirmationPresented = false

    var body: some View {
        Button(action: {
            self.isConfirmationPresented = true
        }) {
            Text("Remove Profile")
        }
        .foregroundColor(.red)
        .alert(isPresented: $isConfirmationPresented) {
            Alert(
                title: Text("Are you sure you want to remove the profile?"),
                primaryButton: .destructive(Text("Remove profile"), action: {
                    self.isConfirmationPresented = false
                    self.model.buttonRemoveProfileTapped()
                }),
                secondaryButton: .cancel()
            )
        }
    }
}

final class TunnelViewModel: ObservableObject {
    @Published var isEnabled = false
    @Published var isStarted = false

    @Published private(set) var status: String = "Unknown"

    @Published var isLoading = false
    @Published var isShowingError = false
    @Published private(set) var errorTitle = ""
    @Published private(set) var errorMessage = ""

    private let service: VPNConfigurationService
    private let tunnel: NETunnelProviderManager

    private var observer: AnyObject?
    private var bag = [AnyCancellable]()

    init(service: VPNConfigurationService = .shared, tunnel: NETunnelProviderManager) {
        self.service = service
        self.tunnel = tunnel

        self.refresh()

        // Register to be notified of changes in the tunnel status.
        observer = NotificationCenter.default
            .addObserver(forName: .NEVPNStatusDidChange, object: tunnel.connection, queue: OperationQueue.main) { [weak self] _ in
                self?.refresh()
        }

        $isEnabled.sink { [weak self] in
            self?.setEnabled($0)
        }.store(in: &bag)

        self.sayHelloToTunnel()
    }

    private func refresh() {
        self.status = tunnel.connection.status.description
        self.isEnabled = tunnel.isEnabled
        self.isStarted = tunnel.connection.status != .disconnected && tunnel.connection.status != .invalid
    }

    private func setEnabled(_ isEnabled: Bool) {
        tunnel.isEnabled = isEnabled
        isLoading = true
        tunnel.saveToPreferences { [weak self] error in
            guard let self = self else { return }
            self.isLoading = false
            if let error = error {
                self.showError(title: "Failed to \(isEnabled ? "enable" : "disable") VPN", message: error.localizedDescription)
                self.errorMessage = error.localizedDescription
                return
            }
        }
    }

    func buttonStartTapped() {
        do {
            try tunnel.connection.startVPNTunnel()
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

    private func showError(title: String, message: String) {
        self.errorTitle = title
        self.errorMessage = message
        self.isShowingError = true
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

struct TunnelView_Previews: PreviewProvider {
    static var previews: some View {
        TunnelStatusView(model: .init(tunnel: .init()))
    }
}
