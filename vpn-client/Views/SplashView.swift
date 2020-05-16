// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import NetworkExtension

struct SplashView: View {
    @ObservedObject var service: VPNConfigurationService = .shared

    @State private var isLoading = false
    @State private var isShowingError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack {
            Text("BestVPN")
                .font(.largeTitle)
                .fontWeight(.heavy)
            Spacer().frame(height: 32)
            HStack {
                Text("Loading profiles…")
                Spinner(isAnimating: $isLoading, color: .label, style: .medium)
            }
        }
        .onAppear(perform: refresh)
        .alert(isPresented: $isShowingError) {
            Alert(
                title: Text("Failed to load profiles"),
                message: Text(errorMessage),
                primaryButton: .default(Text("Retry"), action: refresh),
                secondaryButton: .cancel()
            )
        }
    }

    private func refresh() {
        isLoading = true
        service.refresh {
            self.isLoading = false
            switch $0 {
            case .success:
                break // Handled by RouterView
            case let .failure(error):
                self.errorMessage = error.localizedDescription
                self.isShowingError = true
            }
        }
    }
}

struct SplashView_Previews: PreviewProvider {
    static var previews: some View {
        SplashView()
    }
}
