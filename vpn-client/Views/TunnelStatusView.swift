// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import NetworkExtension

struct TunnelStatusView: View {
    let tunnel: NETunnelProviderManager
    @ObservedObject var service: VPNConfigurationService = .shared

    var body: some View {
        NavigationView {
            Form {
                ButtonRemoveProfile()
            }
            .navigationBarTitle("VPN Status")
        }
    }
}

private struct ButtonRemoveProfile: View {
    @ObservedObject var service: VPNConfigurationService = .shared

    @State private var isShowingRemoveConfirmationAlert = false
    @State private var isRemovingProfile = false
    @State private var isPresented = false
    @State private var isShowingError = false
    @State private var errorMessage = ""

    var body: some View {
        Button(action: {
            self.isShowingRemoveConfirmationAlert = true
        }) {
            ZStack {
                Text("Remove Profile")
                    .opacity(isRemovingProfile ? 0 : 1)
                    .disabled(isRemovingProfile)
                Spinner(isAnimating: $isRemovingProfile, color: .label, style: .medium)
            }
        }
        .foregroundColor(.red)
        .alert(isPresented: $isShowingError) {
            Alert(
                title: Text("Failed to install a profile"),
                message: Text(errorMessage),
                dismissButton: .cancel()
            )
        }
        .alert(isPresented: $isShowingRemoveConfirmationAlert) {
            Alert(
                title: Text("Are you sure you want to remove the profile?"),
                primaryButton: .destructive(Text("Remove profile"), action: {
                    self.isPresented = false
                    self.removeProfile()
                }),
                secondaryButton: .cancel()
            )
        }
    }

    private func removeProfile() {
        isRemovingProfile = true
        service.removeProfile {
            self.isRemovingProfile = false
            switch $0 {
            case .success:
                break // Do nothing, router will show what's next
            case let .failure(error):
                self.errorMessage = error.localizedDescription
                self.isShowingError = true
            }
        }
    }
}

struct TunnelView_Previews: PreviewProvider {
    static var previews: some View {
        TunnelStatusView(tunnel: NETunnelProviderManager())
    }
}
