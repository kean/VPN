// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation
import CryptoKit

// WARNING: This is a simplified example, don't use it as a reference.
public enum Cipher {

    /// WARNING: This is simplified example, don't do this in production!
    ///
    /// A "pre-shared" symmetric key.
    public static let key = SymmetricKey(data: Data(base64Encoded: "KGiEbfJODclOCzUVfWXBO7Y/ohnEVxf7+RnwaAA1/78=")!)

    // WARNING: This is a simplified example, don't use it as a reference.
    public static func encrypt(_ data: Data, key: SymmetricKey) throws -> Data {
        try ChaChaPoly.seal(data, using: key).combined
    }

    // WARNING: This is a simplified example, don't use it as a reference.
    public static func decrypt(_ data: Data, key: SymmetricKey) throws -> Data {
        try ChaChaPoly.open(ChaChaPoly.SealedBox(combined: data), using: key)
    }
}

public extension SymmetricKey {
    /// A Data instance created safely from the contiguous bytes without making any copies.
    var dataRepresentation: Data {
        return self.withUnsafeBytes { bytes in
            let cfdata = CFDataCreateWithBytesNoCopy(nil, bytes.baseAddress?.assumingMemoryBound(to: UInt8.self), bytes.count, kCFAllocatorNull)
            return ((cfdata as NSData?) as Data?) ?? Data()
        }
    }
}
