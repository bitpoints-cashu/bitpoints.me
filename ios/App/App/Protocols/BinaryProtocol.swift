//
// BinaryProtocol.swift
// bitpoints.me
//
// Ported from bitchat for cross-platform compatibility
//

import Foundation
import Compression

extension Data {
    func trimmingNullBytes() -> Data {
        // Find the first null byte
        if let nullIndex = self.firstIndex(of: 0) {
            return self.prefix(nullIndex)
        }
        return self
    }
}

/// Implements binary encoding and decoding for BitChat protocol messages.
/// Provides static methods for converting between BitchatPacket objects and
/// their binary wire format representation.
/// - Note: All multi-byte values use network byte order (big-endian)
struct BinaryProtocol {
    static let headerSize = 13
    static let senderIDSize = 8
    static let recipientIDSize = 8
    static let signatureSize = 64

    struct Flags {
        static let hasRecipient: UInt8 = 0x01
        static let hasSignature: UInt8 = 0x02
        static let isCompressed: UInt8 = 0x04
    }

    // Encode BitchatPacket to binary format
    static func encode(_ packet: BitchatPacket, padding: Bool = true) -> Data? {
        var data = Data()

        // Try to compress payload if beneficial
        var payload = packet.payload
        var originalPayloadSize: UInt16? = nil
        var isCompressed = false

        if CompressionUtil.shouldCompress(payload) {
            if let compressedPayload = CompressionUtil.compress(payload) {
                // Store original size for decompression (2 bytes after payload)
                originalPayloadSize = UInt16(payload.count)
                payload = compressedPayload
                isCompressed = true
            }
        }

        // Header
        // Reserve capacity to reduce reallocations. Estimate base size conservatively.
        // header(13) + sender(8) + opt recipient(8) + opt originalSize(2) + payload + opt signature(64) + up to 255 pad
        let estimatedPayload = payload.count + (isCompressed ? 2 : 0)
        let estimated = headerSize + senderIDSize + (packet.recipientID == nil ? 0 : recipientIDSize) + estimatedPayload + (packet.signature == nil ? 0 : signatureSize) + 255
        data.reserveCapacity(estimated)
        data.append(packet.version)
        data.append(packet.type)
        data.append(packet.ttl)

        // Timestamp (8 bytes, big-endian)
        for i in (0..<8).reversed() {
            data.append(UInt8((packet.timestamp >> (i * 8)) & 0xFF))
        }

        // Flags
        var flags: UInt8 = 0
        if packet.recipientID != nil {
            flags |= Flags.hasRecipient
        }
        if packet.signature != nil {
            flags |= Flags.hasSignature
        }
        if isCompressed {
            flags |= Flags.isCompressed
        }
        data.append(flags)

        // Payload length (2 bytes, big-endian) - includes original size if compressed
        let payloadDataSize = payload.count + (isCompressed ? 2 : 0)
        let payloadLength = UInt16(payloadDataSize)

        data.append(UInt8((payloadLength >> 8) & 0xFF))
        data.append(UInt8(payloadLength & 0xFF))

        // SenderID (exactly 8 bytes)
        let senderBytes = packet.senderID.prefix(senderIDSize)
        data.append(senderBytes)
        if senderBytes.count < senderIDSize {
            data.append(Data(repeating: 0, count: senderIDSize - senderBytes.count))
        }

        // RecipientID (if present)
        if let recipientID = packet.recipientID {
            let recipientBytes = recipientID.prefix(recipientIDSize)
            data.append(recipientBytes)
            if recipientBytes.count < recipientIDSize {
                data.append(Data(repeating: 0, count: recipientIDSize - recipientBytes.count))
            }
        }

        // Payload (with original size prepended if compressed)
        if isCompressed, let originalSize = originalPayloadSize {
            // Prepend original size (2 bytes, big-endian)
            data.append(UInt8((originalSize >> 8) & 0xFF))
            data.append(UInt8(originalSize & 0xFF))
        }
        data.append(payload)

        // Signature (if present)
        if let signature = packet.signature {
            data.append(signature.prefix(signatureSize))
        }

        // Apply padding to standard block sizes for traffic analysis resistance
        if padding {
            let optimalSize = MessagePadding.optimalBlockSize(for: data.count)
            let paddedData = MessagePadding.pad(data, toSize: optimalSize)
            return paddedData
        } else {
            // Caller explicitly requested no padding (e.g., BLE write path)
            return data
        }
    }

    // Decode binary data to BitchatPacket
    static func decode(_ data: Data) -> BitchatPacket? {
        // Try decode as-is first (robust when padding wasn't applied)
        if let pkt = decodeCore(data) { return pkt }
        // If that fails, try after removing padding
        let unpadded = MessagePadding.unpad(data)
        if unpadded as NSData === data as NSData { return nil }
        return decodeCore(unpadded)
    }

    // Core decoding implementation used by decode(_:) with and without padding removal
    private static func decodeCore(_ raw: Data) -> BitchatPacket? {
        // Minimum size: header + senderID
        guard raw.count >= headerSize + senderIDSize else { return nil }

        return raw.withUnsafeBytes { (buf: UnsafeRawBufferPointer) -> BitchatPacket? in
            guard let base = buf.baseAddress else { return nil }
            var offset = 0
            func require(_ n: Int) -> Bool { offset + n <= buf.count }
            // Read single byte
            func read8() -> UInt8? {
                guard require(1) else { return nil }
                let v = base.advanced(by: offset).assumingMemoryBound(to: UInt8.self).pointee
                offset += 1
                return v
            }
            // Read big-endian 16-bit
            func read16() -> UInt16? {
                guard require(2) else { return nil }
                let p = base.advanced(by: offset).assumingMemoryBound(to: UInt8.self)
                let v = (UInt16(p[0]) << 8) | UInt16(p[1])
                offset += 2
                return v
            }
            // Copy N bytes into Data
            func readData(_ n: Int) -> Data? {
                guard require(n) else { return nil }
                let ptr = base.advanced(by: offset)
                let d = Data(bytes: ptr, count: n)
                offset += n
                return d
            }

            // Version
            guard let version = read8(), version == 1 else { return nil }
            guard let type = read8() else { return nil }
            guard let ttl = read8() else { return nil }

            // Timestamp 8 bytes BE
            guard require(8) else { return nil }
            var ts: UInt64 = 0
            for _ in 0..<8 {
                guard let b = read8() else { return nil }
                ts = (ts << 8) | UInt64(b)
            }

            // Flags
            guard let flags = read8() else { return nil }
            let hasRecipient = (flags & Flags.hasRecipient) != 0
            let hasSignature = (flags & Flags.hasSignature) != 0
            let isCompressed = (flags & Flags.isCompressed) != 0

            // Payload length
            guard let payloadLen = read16(), payloadLen <= 65535 else { return nil }

            // SenderID
            guard let senderID = readData(senderIDSize) else { return nil }

            // Recipient
            var recipientID: Data? = nil
            if hasRecipient {
                recipientID = readData(recipientIDSize)
                if recipientID == nil { return nil }
            }

            // Payload
            let payload: Data
            if isCompressed {
                // Need original size (2 bytes)
                guard let origSize16 = read16() else { return nil }
                let originalSize = Int(origSize16)
                guard originalSize >= 0 && originalSize <= 1_048_576 else { return nil }
                let compSize = Int(payloadLen) - 2
                guard compSize >= 0, let compressed = readData(compSize) else { return nil }
                guard let decompressed = CompressionUtil.decompress(compressed, originalSize: originalSize),
                      decompressed.count == originalSize else { return nil }
                payload = decompressed
            } else {
                guard let p = readData(Int(payloadLen)) else { return nil }
                payload = p
            }

            // Signature
            var signature: Data? = nil
            if hasSignature {
                signature = readData(signatureSize)
                if signature == nil { return nil }
            }

            guard offset <= buf.count else { return nil }

            return BitchatPacket(
                type: type,
                senderID: senderID,
                recipientID: recipientID,
                timestamp: ts,
                payload: payload,
                signature: signature,
                ttl: ttl
            )
        }
    }
}
