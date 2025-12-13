import Foundation

public enum Base64URL {
    public static func encode(_ data: Data) -> String {
        let base = data.base64EncodedString()
        return base
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    public static func decode(_ string: String) -> Data? {
        var padded = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - (padded.count % 4)) % 4
        padded.append(String(repeating: "=", count: padding))
        return Data(base64Encoded: padded)
    }
}

