// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import NetworkExtension

struct TunnelView: View {
    let tunnel: NETunnelProviderManager

    var body: some View {
        Text("Profile Installed")
    }
}

struct TunnelView_Previews: PreviewProvider {
    static var previews: some View {
        TunnelView(tunnel: NETunnelProviderManager())
    }
}
