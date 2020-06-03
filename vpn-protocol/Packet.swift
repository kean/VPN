// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation

enum PacketCode: UInt8 {
    /// A control packet containing client authentication request (JSON).
    case clientAuthRequest = 0x01
    /// A control packet containing server authentication response (JSON).
    case serverAuthResponse = 0x02
    /// A data packet containing encrypted IP packets (raw bytes).
    case data = 0x03

    /// Initilizes the code code with the given UDP packet contents.
    init(packet: Data) throws {
        guard packet.count > 0 else {
            throw PacketParsingError.notEnoughData
        }
        guard let code = PacketCode(rawValue: packet[0]) else {
            throw PacketParsingError.invalidPacketCode
        }
        self = code
    }
}

enum PacketParsingError: Error {
    case notEnoughData
    case invalidPacketCode
}

struct Packets {
    struct ClientAuthRequest: Codable {
        let login: String
        let password: String
    }

    struct ServerAuthResponse: Codable {
        let isOK: Bool
    }

    typealias Data = Foundation.Data
}
