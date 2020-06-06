// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation

public enum PacketCode: UInt8 {
    /// A control packet containing client authentication request (JSON).
    case clientAuthRequest = 0x01
    /// A control packet containing server authentication response (JSON).
    case serverAuthResponse = 0x02
    /// A data packet containing encrypted IP packets (raw bytes).
    case data = 0x03

    /// Initilizes the code code with the given UDP packet contents.
    public init(datagram: Data) throws {
        guard datagram.count > 0 else {
            throw PacketParsingError.notEnoughData
        }
        guard let code = PacketCode(rawValue: datagram[0]) else {
            throw PacketParsingError.invalidPacketCode
        }
        self = code
    }
}

public enum PacketParsingError: Error {
    case notEnoughData
    case invalidPacketCode
}

public struct Packets {
    public struct ClientAuthRequest: Codable {
        public let login: String
        public let password: String

        public init(login: String, password: String) {
            self.login = login
            self.password = password
        }

        public func datagram() throws -> Data {
            var data = Data()
            data.append(PacketCode.clientAuthRequest.rawValue)
            let json = try JSONEncoder().encode(self)
            data.append(json)
            return data
        }
    }

    public struct ServerAuthResponse: Codable {
        public let isOK: Bool
        public let address: String

        public init(datagram: Data) throws {
            #warning("TODO: implement")
            fatalError()
        }
    }

    public typealias Data = Foundation.Data
}
