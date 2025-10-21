//
// DataExtensions.swift
// bitpoints.me
//
// Utility extensions for Data type
//

import Foundation
import CryptoKit

extension Data {
    /// Convert Data to hex string
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }

    /// Create Data from hex string
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        var i = hexString.startIndex
        for _ in 0..<len {
            let j = hexString.index(i, offsetBy: 2)
            let bytes = hexString[i..<j]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
            i = j
        }
        self = data
    }

    /// Generate SHA256 fingerprint (first 8 bytes of SHA256 hash)
    func sha256Fingerprint() -> String {
        let hash = SHA256.hash(data: self)
        return Data(hash).prefix(8).hexEncodedString()
    }
}
