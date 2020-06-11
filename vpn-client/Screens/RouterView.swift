// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import SwiftUI

struct RouterView: View {
    @ObservedObject var service: VPNConfigurationService = .shared

    var body: some View {
        if !service.isStarted {
            return AnyView(SplashView())
        } else {
            if let tunnel = service.tunnel {
                return AnyView(TunnelDetailsView(model: TunnelViewModel(tunnel: tunnel)))
            } else {
                return AnyView(WelcomeView())
            }
        }
    }
}

struct RouterView_Previews: PreviewProvider {
    static var previews: some View {
        RouterView()
    }
}
