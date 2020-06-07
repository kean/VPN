// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation
import CryptoKit

// WARNING: This is a simplified example, don't use it as a reference.
public final class Cipher {
    private let key: SymmetricKey

    public init(key: SymmetricKey) {
        self.key = key
    }

    // WARNING: This is a simplified example, don't use it as a reference.
    public func encrypt(_ data: Data) throws -> Data {
        try ChaChaPoly.seal(data, using: key).combined
    }

    // WARNING: This is a simplified example, don't use it as a reference.
    public func decrypt(_ data: Data) throws -> Data {
        try ChaChaPoly.open(ChaChaPoly.SealedBox(combined: data), using: key)
    }
}
