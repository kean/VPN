// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct WelcomeView: View {
    let service: VPNConfigurationService = .shared

    @State private var isLoading = false
    @State private var isShowingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            VStack {
                header
                Spacer(minLength: 0)
                buttonInstall
                Spacer().frame(height: 16)
            }.padding()
        }
    }

    private var header: some View {
        VStack {
            Text("BestVPN")
                .font(.largeTitle)
                .fontWeight(.heavy)
            HStack(spacing: 20) {
                Image("icon-vpn")
                    .resizable()
                    .frame(width: 50, height: 50)
                VStack(alignment: .leading) {
                    Text("Custom VPN solution")
                        .font(.headline)
                    Text("Powered by Network Extension and SwiftNIO")
                }
            }
        }
    }

    private var buttonInstall: some View {
        PrimaryButton(
            title: "Install VPN Profile",
            action: self.installProfile,
            isLoading: $isLoading
        ).alert(isPresented: $isShowingError) {
            Alert(
                title: Text("Failed to install a profile"),
                message: Text(errorMessage),
                dismissButton: .cancel()
            )
        }
    }

    private func installProfile() {
        isLoading = true

        service.installProfile { result in
            self.isLoading = false
            switch result {
            case .success:
                break // Do nothing, router will show what's next
            case let .failure(error):
                self.errorMessage = error.localizedDescription
                self.isShowingError = true
            }
        }
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
    }
}
