// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation
import NetworkExtension

final class Tunnel {
    init(flow: NEPacketTunnelFlow)
}

enum TunnelError: Swift.Error {
    case parameterMissing(String)
}
