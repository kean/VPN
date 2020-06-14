// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation
import CryptoKit

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

public struct Header {
    public let code: PacketCode

    public static let length = 1

    public init(code: PacketCode) {
        self.code = code
    }
}

public enum Body {
    public struct ClientAuthRequest: Codable {
        public let login: String
        public let password: String

        public init(login: String, password: String) {
            self.login = login
            self.password = password
        }
    }

    public struct ServerAuthResponse: Codable {
        public let isOK: Bool

        public init(isOK: Bool) {
            self.isOK = isOK
        }
    }

    public typealias Data = Foundation.Data
}

// MARK: - Encoder

public enum MessageEncoder {
    public static func encode<Body: Codable>(header: Header, body: Body, key: SymmetricKey) throws -> Data {
        try encode(header: header, body: JSONEncoder().encode(body), key: key)
    }

    public static func encode(header: Header, body: Data, key: SymmetricKey) throws -> Data {
        var data = Data()

        // Header
        data.append(header.code.rawValue)

        // Body
        let body = try Cipher.encrypt(body, key: key)
        data.append(body)

        return data
    }
}

public enum MessageDecoder {
    /// Decrypts and decodes the body of the given datagram.
    public static func decode<T: Decodable>(_ type: T.Type, datagram: Data, key: SymmetricKey) throws -> T {
        let data = try Cipher.decrypt(datagram[Header.length...], key: key)
        return try JSONDecoder().decode(type, from: data)
    }
}
